//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/IAddressRegistry.sol";
import "./interfaces/IGameRegistry.sol";

/**
 * @title Oparcade
 * @notice This manages the token deposit and claim from/to the users
 * @author David Lee
 */
contract Oparcade is OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
  using ECDSAUpgradeable for bytes32;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  event Deposit(address indexed by, uint256 indexed gid, address indexed token, uint256 amount);
  event Claim(address indexed by, uint256 indexed gid, address indexed token, uint256 amount);
  event PlatformFeeUpdated(
    address indexed by,
    address indexed oldFeeRecipient,
    uint256 oldPlatformFee,
    address indexed newFeeRecipient,
    uint256 newPlatformFee
  );

  /// @dev AddressRegistry
  IAddressRegistry public addressRegistry;

  /// @dev Signature -> Bool
  mapping(bytes => bool) public signatures;

  /// @dev Platform fee
  uint16 public platformFee;

  /// @dev Platform fee recipient
  address public feeRecipient;

  function initialize(
    address _addressRegistry,
    address _feeRecipient,
    uint16 _platformFee
  ) public initializer {
    __Ownable_init();
    __ReentrancyGuard_init();
    __Pausable_init();

    require(_addressRegistry != address(0), "Invalid AddressRegistry");
    require(_feeRecipient != address(0) || _platformFee == 0, "fee recipient not set");

    // initialize AddressRegistery
    addressRegistry = IAddressRegistry(_addressRegistry);

    // initialize fee and recipient
    feeRecipient = _feeRecipient;
    platformFee = _platformFee;
  }

  /**
   * @notice Deposit ERC20 tokens from user
   * @dev Only tokens registered in GameRegistry with an amount greater than zero is valid for the deposit
   * @param _gid Game ID
   * @param _token Token address to deposit
   */
  function deposit(uint256 _gid, address _token) external whenNotPaused {
    // get token amount to deposit
    uint256 depositTokenAmount = IGameRegistry(addressRegistry.gameRegistry()).depositTokenAmount(_gid, _token);

    // check if the token address is valid
    require(depositTokenAmount > 0, "Invalid deposit token");

    // transfer tokens
    IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(this), depositTokenAmount);

    emit Deposit(msg.sender, _gid, _token, depositTokenAmount);
  }

  /**
   * @notice Allow for the users to claim ERC20 tokens
   * @dev Only winners with the valid signature are able to claim
   * @param _gid Game ID
   * @param _winner Winner address
   * @param _token Token address to claim
   * @param _amount Token amount to claim
   * @param _nonce Nonce
   * @param _signature Signature
   */
  function claim(
    uint256 _gid,
    address _winner,
    address _token,
    uint256 _amount,
    uint256 _nonce,
    bytes calldata _signature
  ) external nonReentrant whenNotPaused {
    // check if nonce is already used
    require(!signatures[_signature], "Already used signature");
    signatures[_signature] = true;

    // check if msg.sender is the _winner
    require(msg.sender == _winner, "Only winner can claim");

    // check signer
    address maintainer = addressRegistry.maintainer();
    bytes32 data = keccak256(abi.encodePacked(_gid, msg.sender, _token, _amount, _nonce));
    require(data.toEthSignedMessageHash().recover(_signature) == maintainer, "Wrong signer");

    // calculate payment amount
    uint256 feeAmount = (_amount * platformFee) / 1000;
    uint256 winnerAmount = _amount - feeAmount;

    // transfer payment
    IERC20Upgradeable(_token).safeTransfer(feeRecipient, feeAmount);
    IERC20Upgradeable(_token).safeTransfer(msg.sender, winnerAmount);

    emit Claim(msg.sender, _gid, _token, _amount);
  }

  /**
   * @notice Update platform fee
   *
   * @dev Only owner
   * @dev Allow zero recipient address only of fee is also zero
   *
   * @param _platformFee platform fee
   */
  function updatePlatformFee(address _feeRecipient, uint16 _platformFee) external onlyOwner {
    require(_feeRecipient != address(0) || _platformFee == 0, "fee recipient not set");

    emit PlatformFeeUpdated(msg.sender, feeRecipient, platformFee, _feeRecipient, _platformFee);

    feeRecipient = _feeRecipient;
    platformFee = _platformFee;
  }

  /**
   * @notice Pause Oparcade
   *
   * @dev Only owner
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @notice Resume Oparcade
   *
   * @dev Only owner
   */
  function unpause() external onlyOwner {
    _unpause();
  }
}
