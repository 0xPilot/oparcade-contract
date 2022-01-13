//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title AddressRegistry
 * @notice This stores all addresses in the Oparcade
 * @author David Lee
 */
contract AddressRegistry is OwnableUpgradeable {
  address public oparcade;
  address public tokenRegistry;
  address public maintainer;

  function initialize() public initializer {
    __Ownable_init();
  }

  /**
   * @notice Update Oparcade contract address
   * @dev Only owner
   * @param _oparcade Oparcade contract address
   */
  function updateOparcade(address _oparcade) external onlyOwner {
    oparcade = _oparcade;
  }

  /**
   * @notice Update TokenRegistry contract address
   * @dev onlyOwner
   * @param _tokenRegistry TokenRegistry contract address
   */
  function updateTokenRegistry(address _tokenRegistry) external onlyOwner {
    tokenRegistry = _tokenRegistry;
  }

  /**
   * @notice Update maintainer address
   * @dev Only owner
   * @param _maintainer Maintainer address
   */
  function updateMaintainer(address _maintainer) external onlyOwner {
    maintainer = _maintainer;
  }
}
