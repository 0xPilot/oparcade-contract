//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title GameRegistry
 * @notice This stores all games in the Oparcade
 * @author David Lee
 */
contract GameRegistry is OwnableUpgradeable {
  event AddGame(uint256 indexed gid, string gameName);
  event RemoveGame(uint256 indexed gid, string gameName);
  event UpdateDepositAmount(uint256 indexed gid, address indexed token, uint256 amount);
  event UpdateClaimableAmount(uint256 indexed gid, address indexed token, bool isClaimable);

  /// @dev Game name array
  string[] public games;

  /// @dev Game ID -> Token address -> Deposit amount
  mapping(uint256 => mapping(address => uint256)) public depositAmount;

  /// @dev Game ID -> Token address -> Bool
  mapping(uint256 => mapping(address => bool)) public claimable;

  /// @dev Game ID -> Bool
  mapping(uint256 => bool) public isDeprecatedGame;

  modifier onlyValidGID(uint256 _gid) {
    require(_gid < games.length, "Invalid game index");
    _;
  }

  function initialize() public initializer {
    __Ownable_init();
  }

  /**
   * @notice Add new game
   * @param _gameName Game name to add
   */
  function addGame(string memory _gameName) external onlyOwner returns (uint256 gid) {
    games.push(_gameName);
    gid = games.length - 1;

    emit AddGame(gid, _gameName);
  }

  /**
   * @notice Remove game
   * @dev Game is not removed from the games array, just set it deprecated
   */
  function removeGame(uint256 _gid) external onlyOwner onlyValidGID(_gid) {
    // remove game
    isDeprecatedGame[_gid] = true;

    emit RemoveGame(_gid, games[_gid]);
  }

  /**
   * @notice Update deposit token amount
   * @dev Only owner
   * @dev Only tokens with an amount greater than zero is valid for the deposit
   * @param _gid Game ID
   * @param _token Token address to allow/disallow the deposit
   * @param _amount Token amount
   */
  function updateDepositAmount(
    uint256 _gid,
    address _token,
    uint256 _amount
  ) external onlyOwner onlyValidGID(_gid) {
    depositAmount[_gid][_token] = _amount;

    emit UpdateDepositAmount(_gid, _token, _amount);
  }

  /**
   * @notice Update claimable token amount
   * @dev Only owner
   * @param _gid Game ID
   * @param _token Token address to allow/disallow the deposit
   * @param _isClaimable true: claimable false: not claimable
   */
  function updateClaimableAmount(
    uint256 _gid,
    address _token,
    bool _isClaimable
  ) external onlyOwner onlyValidGID(_gid) {
    claimable[_gid][_token] = _isClaimable;

    emit UpdateClaimableAmount(_gid, _token, _isClaimable);
  }

  /**
   * @notice Returns the number of games added in games array
   */
  function gameLength() external view returns (uint256) {
    return games.length;
  }
}
