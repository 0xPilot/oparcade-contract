//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/IAddressRegistry.sol";
import "./interfaces/ITokenRegistry.sol";

/**
 * @title Oparcade
 * @notice This manages the token deposit and claim from the users
 * @author David Lee
 */
contract Oparcade is ReentrancyGuardUpgradeable {
  using ECDSAUpgradeable for bytes32;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  event Deposit(address indexed user, address indexed token, uint256 amount);
  event Claim(address indexed winner, address indexed token, uint256 amount);

  /// @dev AddressRegistry
  IAddressRegistry public addressRegistry;

  /// @dev TokenRegistry
  ITokenRegistry public tokenRegistry;

  /// @dev User -> Deposit amount
  mapping(address => uint256) private userBalance;

  /// @dev User -> Nonce -> Bool
  mapping(address => mapping(uint256 => bool)) public nonces;

  function initialize(address _addressRegistry) public initializer {
    __ReentrancyGuard_init();

    addressRegistry = IAddressRegistry(_addressRegistry);
    tokenRegistry = ITokenRegistry(addressRegistry.tokenRegistry());
  }

  /**
   * @notice Deposit ERC20 tokens from user
   * @dev Only tokens registered in TokenRegistry with an amount greater than zero is valid for the deposit
   * @param _token Token address to deposit
   */
  function deposit(address _token) external {
    // get token amount to deposit
    uint256 depositTokenAmount = tokenRegistry.depositTokenAmount(_token);

    // check if token address is valid
    require(depositTokenAmount > 0, "Token is invalid");

    // transfer tokens
    userBalance[msg.sender] += depositTokenAmount;
    IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(this), depositTokenAmount);

    emit Deposit(msg.sender, _token, depositTokenAmount);
  }

  /**
   * @notice Allow for the users to claim ERC20 tokens
   * @dev Only winners with the valid signature are able to claim
   * @param _winner Winner address
   * @param _token Token address to claim
   * @param _amount Token amount to claim
   * @param _nonce Nonce
   * @param _signature Signature
   */
  function claim(
    address _winner,
    address _token,
    uint256 _amount,
    uint256 _nonce,
    bytes calldata _signature
  ) external nonReentrant {
    // check if nonce is already used
    require(!nonces[_winner][_nonce], "Already used nonce");
    nonces[_winner][_nonce] = true;

    // check if msg.sender is the _winner
    require(msg.sender == _winner, "Only winner can claim");

    // check signer
    address maintainer = addressRegistry.maintainer();
    bytes32 data = keccak256(abi.encodePacked(msg.sender, _token, _amount, _nonce));
    require(data.toEthSignedMessageHash().recover(_signature) == maintainer, "Wrong signer");

    // transfer tokens to the winner
    IERC20Upgradeable(_token).safeTransfer(msg.sender, _amount);

    emit Claim(msg.sender, _token, _amount);
  }
}
