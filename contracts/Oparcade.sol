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

  /// @dev AddressRegistry
  IAddressRegistry public addressRegistry;

  /// @dev GameRegisetry
  IGameRegistry public gameRegistry;

  /// @dev Signature -> Bool
  mapping(bytes => bool) public signatures;

  function initialize(address _addressRegistry) public initializer {
    __Ownable_init();
    __ReentrancyGuard_init();
    __Pausable_init();

    addressRegistry = IAddressRegistry(_addressRegistry);
    gameRegistry = IGameRegistry(addressRegistry.gameRegistry());
  }

  /**
   * @notice Deposit ERC20 tokens from user
   * @dev Only tokens registered in GameRegistry with an amount greater than zero is valid for the deposit
   * @param _gid Game ID
   * @param _token Token address to deposit
   */
  function deposit(uint256 _gid, address _token) external whenNotPaused {
    // get token amount to deposit
    uint256 depositAmount = gameRegistry.depositAmount(_gid, _token);

    // check if the token address is valid
    require(depositAmount > 0, "Invalid deposit token");

    // transfer tokens
    IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(this), depositAmount);

    emit Deposit(msg.sender, _gid, _token, depositAmount);
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
    require(!signatures[_signature], "Already used nonce");
    signatures[_signature] = true;

    // check if msg.sender is the _winner
    require(msg.sender == _winner, "Only winner can claim");

    // check signer
    address maintainer = addressRegistry.maintainer();
    bytes32 data = keccak256(abi.encodePacked(_gid, msg.sender, _token, _amount, _nonce));
    require(data.toEthSignedMessageHash().recover(_signature) == maintainer, "Wrong signer");

    // transfer tokens to the winner
    IERC20Upgradeable(_token).safeTransfer(msg.sender, _amount);

    emit Claim(msg.sender, _gid, _token, _amount);
  }

  /**
   * @notice Pause Oparcade
   *
   * @dev Only onwer
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @notice Resume Oparcade
   *
   * @dev Only onwer
   */
  function unpause() external onlyOwner {
    _unpause();
  }
}
