//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title AddressRegistry
 * @notice This stores all addresses in the Oparcade
 * @author David Lee
 */
contract AddressRegistry is OwnableUpgradeable {
  event UpdateOparcade(address indexed oparcade);
  event UpdateGameRegistry(address indexed gameRegistry);
  event UpdateMaintainer(address indexed maintainer);

  /// @dev Oparcade contract address, can be zero if not set
  address public oparcade;

  /// @dev GameRegistry contract address, can be zero if not set
  address public gameRegistry;

  /// @dev Maintainer address, can be zero if not set
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

    emit UpdateOparcade(_oparcade);
  }

  /**
   * @notice Update GameRegistry contract address
   * @dev Only owner
   * @param _gameRegistry TokenRegistry contract address
   */
  function updateGameRegistry(address _gameRegistry) external onlyOwner {
    gameRegistry = _gameRegistry;

    emit UpdateGameRegistry(_gameRegistry);
  }

  /**
   * @notice Update maintainer address
   * @dev Only owner
   * @param _maintainer Maintainer address
   */
  function updateMaintainer(address _maintainer) external onlyOwner {
    maintainer = _maintainer;

    emit UpdateMaintainer(_maintainer);
  }
}
