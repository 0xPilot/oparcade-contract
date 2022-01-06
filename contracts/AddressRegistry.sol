//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AddressRegistry is OwnableUpgradeable {
  address public oparcade;
  address public tokenRegistry;

  function initialize() public initializer {
    __Ownable_init();
  }

  function updateOparcade(address _oparcade) external onlyOwner {
    oparcade = _oparcade;
  }

  function updateTokenRegistry(address _tokenRegistry) external onlyOwner {
    tokenRegistry = _tokenRegistry;
  }
}
