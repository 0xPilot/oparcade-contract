// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title AddressRegistry
 * @notice This stores all addresses in the Oparcade
 * @author David Lee
 */
contract AddressRegistry is OwnableUpgradeable {
  event OparcadeUpdated(address indexed oldOparcade, address indexed newOparcade);
  event GameRegistryUpdated(address indexed oldGameRegistry, address indexed newGameRegistry);
  event MaintainerUpdated(address indexed oldMaintainer, address indexed newMaintainer);
  event TimelockUpdated(address indexed oldTimelock, address indexed newTimelock);

  /// @dev Oparcade contract address, can be zero if not set
  address public oparcade;

  /// @dev GameRegistry contract address, can be zero if not set
  address public gameRegistry;

  /// @dev Maintainer address, can be zero if not set
  address public maintainer;

  /// @dev Timelock contract address, can be zero if not set
  address public timelock;

  function initialize() public initializer {
    __Ownable_init();
  }

  /**
   * @notice Update Oparcade contract address
   * @dev Only owner
   * @param _oparcade Oparcade contract address
   */
  function updateOparcade(address _oparcade) external onlyOwner {
    require(_oparcade != address(0), "!Oparcade");

    emit OparcadeUpdated(oparcade, _oparcade);

    oparcade = _oparcade;
  }

  /**
   * @notice Update GameRegistry contract address
   * @dev Only owner
   * @param _gameRegistry TokenRegistry contract address
   */
  function updateGameRegistry(address _gameRegistry) external onlyOwner {
    require(_gameRegistry != address(0), "!GameRegistry");

    emit GameRegistryUpdated(gameRegistry, _gameRegistry);

    gameRegistry = _gameRegistry;
  }

  /**
   * @notice Update maintainer address
   * @dev Only owner
   * @param _maintainer Maintainer address
   */
  function updateMaintainer(address _maintainer) external onlyOwner {
    require(_maintainer != address(0), "!Maintainer");

    emit MaintainerUpdated(maintainer, _maintainer);

    maintainer = _maintainer;
  }

  /**
   * @notice Update Timelock contract address
   * @dev Only owner
   * @param _timelock Maintainer address
   */
  function updateTimelock(address _timelock) external onlyOwner {
    require(_timelock != address(0), "!Timelock");

    emit TimelockUpdated(timelock, _timelock);

    timelock = _timelock;
  }
}
