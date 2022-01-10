//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/IAddressRegistry.sol";
import "./interfaces/ITokenRegistry.sol";

contract Oparcade is ReentrancyGuardUpgradeable {
  using ECDSAUpgradeable for bytes32;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IAddressRegistry public addressRegistry;
  ITokenRegistry public tokenRegistry;
  mapping(address => uint256) private userBalance;
  mapping(bytes => bool) public signatures;

  function initialize(address _addressRegistry) public initializer {
    __ReentrancyGuard_init();

    addressRegistry = IAddressRegistry(_addressRegistry);
    tokenRegistry = ITokenRegistry(addressRegistry.tokenRegistry());
  }

  function deposit(address _token) external {
    // get token amount to deposit
    uint256 depositTokenAmount = tokenRegistry.depositTokenAmount(_token);

    // check if token address is valid
    require(depositTokenAmount > 0, "Invalid token address");

    // transfer tokens
    userBalance[msg.sender] += depositTokenAmount;
    IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(this), depositTokenAmount);
  }

  function claim(
    address _winner,
    address _token,
    uint256 _amount,
    bytes calldata _signature
  ) external nonReentrant {
    // check if signature is already used
    require(!signatures[_signature], "Already used signature");
    signatures[_signature] = true;

    // check if msg.sender is the _winner
    require(msg.sender == _winner, "Only winner can claim");

    // check signer
    address maintainer = addressRegistry.maintainer();
    bytes32 data = keccak256(abi.encodePacked(msg.sender, _token, _amount));
    require(data.toEthSignedMessageHash().recover(_signature) == maintainer, "Wrong signer");

    // transfer tokens to the winner
    IERC20Upgradeable(_token).safeTransfer(msg.sender, _amount);
  }
}
