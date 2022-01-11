//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title TokenRegistry
 * @notice This stores the token contract addresses available in the Oparcade
 * @author David Lee
 */
contract TokenRegistry is OwnableUpgradeable {
  mapping(address => uint256) public depositTokenAmount;

  function initialize() public initializer {
    __Ownable_init();
  }

  /**
   * @notice Update deposit token information
   * @dev onlyOwner
   * @dev Only tokens with an amount greater than zero is valid for the deposit
   * @param _token Token address to allow/disallow the deposit
   * @param _amount Token amount
   */
  function updateDepositTokenAmount(address _token, uint256 _amount) external onlyOwner {
    depositTokenAmount[_token] = _amount;
  }
}
