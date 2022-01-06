//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract TokenRegistry is OwnableUpgradeable {
  mapping(address => uint256) public depositTokenAmount;

  function initialize() public initializer {
    __Ownable_init();
  }

  function updateDepositTokenAmount(address _token, uint256 _amount) external onlyOwner {
    depositTokenAmount[_token] = _amount;
  }
}
