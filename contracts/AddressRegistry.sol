//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title AddressRegistry
 * @notice This stores all addresses in the Oparcade
 * @author David Lee
 */
contract AddressRegistry is OwnableUpgradeable {
  event OrarcadeUpdated(address indexed by, address indexed oldOparcade, address indexed newOparcade);
  event GameRegistryUpdated(address indexed by, address indexed oldGameRegistry, address indexed newGameRegistry);
  event MaintainerUpdated(address indexed by, address indexed oldMaintainer, address indexed newMaintainer);

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
    address oldOparcade = oparcade;
    oparcade = _oparcade;

    emit OrarcadeUpdated(msg.sender, oldOparcade, _oparcade);
  }

  /**
   * @notice Update GameRegistry contract address
   * @dev Only owner
   * @param _gameRegistry TokenRegistry contract address
   */
  function updateGameRegistry(address _gameRegistry) external onlyOwner {
    address oldGameRegistry = gameRegistry;
    gameRegistry = _gameRegistry;

    emit GameRegistryUpdated(msg.sender, oldGameRegistry, _gameRegistry);
  }

  /**
   * @notice Update maintainer address
   * @dev Only owner
   * @param _maintainer Maintainer address
   */
  function updateMaintainer(address _maintainer) external onlyOwner {
    address oldMaintainer = maintainer;
    maintainer = _maintainer;

    emit MaintainerUpdated(msg.sender, oldMaintainer, _maintainer);
  }
}
