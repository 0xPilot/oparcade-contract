//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title GameRegistry
 * @notice This stores all games in the Oparcade
 * @author David Lee
 */
contract GameRegistry is OwnableUpgradeable {
  event GameAdded(address indexed by, uint256 indexed gid, string gameName);
  event GameRemoved(address indexed by, uint256 indexed gid, string gameName);
  event DepositAmountUpdated(
    address indexed by,
    uint256 indexed gid,
    address indexed token,
    uint256 oldAmount,
    uint256 newAmount
  );
  event ClaimableAmountUpdated(
    address indexed by,
    uint256 indexed gid,
    address indexed token,
    bool oldStatus,
    bool newStatus
  );

  /// @dev Game name array
  string[] public games;

  /// @dev Game ID -> Token address -> Deposit amount
  mapping(uint256 => mapping(address => uint256)) public depositTokenAmount;

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

    emit GameAdded(msg.sender, gid, _gameName);
  }

  /**
   * @notice Remove game
   * @dev Game is not removed from the games array, just set it deprecated
   */
  function removeGame(uint256 _gid) external onlyOwner onlyValidGID(_gid) {
    // remove game
    isDeprecatedGame[_gid] = true;

    emit GameRemoved(msg.sender, _gid, games[_gid]);
  }

  /**
   * @notice Update deposit token amount
   * @dev Only owner
   * @dev Only tokens with an amount greater than zero is valid for the deposit
   * @param _gid Game ID
   * @param _token Token address to allow/disallow the deposit
   * @param _amount Token amount
   */
  function updateDepositTokenAmount(
    uint256 _gid,
    address _token,
    uint256 _amount
  ) external onlyOwner onlyValidGID(_gid) {
    emit DepositAmountUpdated(msg.sender, _gid, _token, depositTokenAmount[_gid][_token], _amount);

    depositTokenAmount[_gid][_token] = _amount;
  }

  /**
   * @notice Update claimable token address
   * @dev Only owner
   * @param _gid Game ID
   * @param _token Token address to allow/disallow the deposit
   * @param _isClaimable true: claimable false: not claimable
   */
  function updateClaimableTokenAddress(
    uint256 _gid,
    address _token,
    bool _isClaimable
  ) external onlyOwner onlyValidGID(_gid) {
    emit ClaimableAmountUpdated(msg.sender, _gid, _token, claimable[_gid][_token], _isClaimable);

    claimable[_gid][_token] = _isClaimable;
  }

  /**
   * @notice Returns the number of games added in games array
   */
  function gameLength() external view returns (uint256) {
    return games.length;
  }
}
