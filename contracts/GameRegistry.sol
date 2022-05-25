// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IAddressRegistry.sol";
import "./interfaces/IOparcade.sol";

/**
 * @title GameRegistry
 * @notice This contract stores all info related to the game and tournament
 * @author David Lee
 */
contract GameRegistry is OwnableUpgradeable {
  event GameAdded(
    address indexed by,
    uint256 indexed gid,
    string gameName,
    address indexed gameCreator,
    uint256 baseGameCreatorFee
  );
  event GameRemoved(
    address indexed by,
    uint256 indexed gid,
    string gameName,
    address indexed gameCreator,
    uint256 baseGameCreatorFee
  );
  event GameCreatorUpdated(
    address indexed by,
    uint256 indexed gid,
    address indexed oldGameCreator,
    address newGameCreator
  );
  event BaseGameCreatorFeeUpdated(
    address indexed by,
    uint256 indexed gid,
    uint256 indexed oldBaseGameCreatorFee,
    uint256 newBaseGameCreatorFee
  );
  event TournamentCreated(
    address indexed by,
    uint256 indexed gid,
    uint256 indexed tid,
    uint256 appliedGameCreatorFee,
    uint256 tournamentCreatorFee
  );
  event DepositAmountUpdated(
    address indexed by,
    uint256 indexed gid,
    uint256 indexed tid,
    address token,
    uint256 oldAmount,
    uint256 newAmount
  );
  event DistributableTokenAddressUpdated(
    address indexed by,
    uint256 indexed gid,
    address indexed token,
    bool oldStatus,
    bool newStatus
  );

  /// @dev Game name array
  string[] public games;

  /// @dev Game ID -> Game creator
  mapping(uint256 => address) public gameCreators;

  /// @dev Game ID -> Base game creator fee
  mapping(uint256 => uint256) public baseGameCreatorFees;

  /// @dev Game ID -> Tournament ID -> Game creator fee applied to the tournament
  mapping(uint256 => mapping(uint256 => uint256)) public appliedGameCreatorFees;

  /// @dev Game ID -> Tournament creator list
  mapping(uint256 => address[]) public tournamentCreators;

  /// @dev Game ID -> Tournament ID -> Tournament creator fee
  mapping(uint256 => mapping(uint256 => uint256)) public tournamentCreatorFees;

  /// @dev Game ID -> Deposit token list
  mapping(uint256 => address[]) public depositTokenList;

  /// @dev Game ID -> Tournament ID -> Token address -> Deposit amount
  mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public depositTokenAmount;

  /// @dev Game ID -> Distributable token list
  mapping(uint256 => address[]) public distributableTokenList;

  /// @dev Game ID -> Token address -> Bool
  mapping(uint256 => mapping(address => bool)) public distributable;

  /// @dev Game ID -> Bool
  mapping(uint256 => bool) public isDeprecatedGame;

  /// @dev AddressRegistry
  IAddressRegistry public addressRegistry;

  modifier onlyValidGID(uint256 _gid) {
    require(_gid < games.length && isDeprecatedGame[_gid] == false, "Invalid game index");
    _;
  }

  modifier onlyValidTID(uint256 _gid, uint256 _tid) {
    require(_tid < tournamentCreators[_gid].length, "Invalid tournament index");
    _;
  }

  function initialize(address _addressRegistry) public initializer {
    __Ownable_init();

    // initialize AddressRegistery
    addressRegistry = IAddressRegistry(_addressRegistry);
  }

  /**
   * @notice Add the new game
   * @param _gameName Game name to add
   * @param _gameCreator Game creator address
   */
  function addGame(
    string memory _gameName,
    address _gameCreator,
    uint256 _baseGameCreatorFee
  ) external onlyOwner returns (uint256 gid) {
    require(bytes(_gameName).length != 0, "Empty game name");
    require(_gameCreator != address(0), "Zero game creator");
    require(
      IOparcade(addressRegistry.oparcade()).platformFee() + _baseGameCreatorFee < 1000,
      "Exceeded game creator fee"
    );

    // add the game
    games.push(_gameName);

    // set the gid
    gid = games.length - 1;

    // set the game creator address and fee
    gameCreators[gid] = _gameCreator;
    baseGameCreatorFees[gid] = _baseGameCreatorFee;

    emit GameAdded(msg.sender, gid, _gameName, _gameCreator, _baseGameCreatorFee);
  }

  /**
   * @notice Remove the exising game
   * @dev Game is not removed from the games array, just set it deprecated
   * @param _gid Game ID
   */
  function removeGame(uint256 _gid) external onlyOwner onlyValidGID(_gid) {
    // remove game
    isDeprecatedGame[_gid] = true;

    emit GameRemoved(msg.sender, _gid, games[_gid], gameCreators[_gid], baseGameCreatorFees[_gid]);
  }

  function updateGameCreator(uint256 _gid, address _gameCreator) external onlyValidGID(_gid) {
    require(msg.sender == gameCreators[_gid], "Only game creator");
    require(_gameCreator != address(0), "Zero game creator address");

    emit GameCreatorUpdated(msg.sender, _gid, gameCreators[_gid], _gameCreator);

    // update the game creator address
    gameCreators[_gid] = _gameCreator;
  }

  function updateBaseGameCreatorFee(uint256 _gid, uint256 _baseGameCreatorFee) external onlyOwner onlyValidGID(_gid) {
    require(
      IOparcade(addressRegistry.oparcade()).platformFee() + _baseGameCreatorFee < 1000,
      "Exceeded game creator fee"
    );

    emit BaseGameCreatorFeeUpdated(msg.sender, _gid, baseGameCreatorFees[_gid], _baseGameCreatorFee);

    // update the game creator fee
    baseGameCreatorFees[_gid] = _baseGameCreatorFee;
  }

  function createTournamentByOP(
    uint256 _gid,
    uint256 _proposedGameCreatorFee,
    uint256 _tournamentCreatorFee
  ) external onlyOwner onlyValidGID(_gid) returns (uint256 tid) {
    tid = _createTournament(_gid, _proposedGameCreatorFee, _tournamentCreatorFee);
  }

  function _createTournament(
    uint256 _gid,
    uint256 _proposedGameCreatorFee,
    uint256 _tournamentCreatorFee
  ) internal returns (uint256 tid) {
    // use baseCreatorFee if _proposedGameCreatorFee is zero
    uint256 appliedGameCreatorFee;
    if (_proposedGameCreatorFee == 0) {
      appliedGameCreatorFee = baseGameCreatorFees[_gid];
    } else {
      appliedGameCreatorFee = _proposedGameCreatorFee;
    }

    // check fees
    require(baseGameCreatorFees[_gid] <= appliedGameCreatorFee, "Low game creator fee applied");
    require(
      IOparcade(addressRegistry.oparcade()).platformFee() + appliedGameCreatorFee + _tournamentCreatorFee < 1000,
      "Exceeded fees"
    );

    // get the new tournament ID
    tid = tournamentCreators[_gid].length;

    // add the tournament creator address and fee
    tournamentCreators[_gid].push(msg.sender);
    appliedGameCreatorFees[_gid][tid] = appliedGameCreatorFee;
    tournamentCreatorFees[_gid][tid] = _tournamentCreatorFee;

    emit TournamentCreated(msg.sender, _gid, tid, appliedGameCreatorFee, _tournamentCreatorFee);
  }

  function createTournamentByUser(
    uint256 _gid,
    uint256 _proposedGameCreatorFee,
    uint256 _tournamentCreatorFee,
    address _depositTokenAddress,
    uint256 _depositTokenAmount
  ) external onlyValidGID(_gid) returns (uint256 tid) {
    tid = _createTournament(_gid, _proposedGameCreatorFee, _tournamentCreatorFee);
    _updateDepositTokenAmount(_gid, tid, _depositTokenAddress, _depositTokenAmount);
  }

  /**
   * @notice Update deposit token amount
   * @dev Only owner
   * @dev Only tokens with an amount greater than zero is valid for the deposit
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _token Token address to allow/disallow the deposit
   * @param _amount Token amount
   */
  function updateDepositTokenAmount(
    uint256 _gid,
    uint256 _tid,
    address _token,
    uint256 _amount
  ) external onlyOwner onlyValidGID(_gid) onlyValidTID(_gid, _tid) {
    _updateDepositTokenAmount(_gid, _tid, _token, _amount);
  }

  function _updateDepositTokenAmount(
    uint256 _gid,
    uint256 _tid,
    address _token,
    uint256 _amount
  ) internal {
    emit DepositAmountUpdated(msg.sender, _gid, _tid, _token, depositTokenAmount[_gid][_tid][_token], _amount);

    // update deposit token list
    if (_amount > 0) {
      if (depositTokenAmount[_gid][_tid][_token] == 0) {
        // add the token into the list only if it's added newly
        depositTokenList[_gid].push(_token);
      }
    } else {
      for (uint256 i; i < depositTokenList[_gid].length; i++) {
        if (_token == depositTokenList[_gid][i]) {
          // remove the token from the list
          depositTokenList[_gid][i] = depositTokenList[_gid][depositTokenList[_gid].length - 1];
          depositTokenList[_gid].pop();
          break;
        }
      }
    }

    // update deposit token amount
    depositTokenAmount[_gid][_tid][_token] = _amount;
  }

  /**
   * @notice Update distributable token address
   * @dev Only owner
   * @param _gid Game ID
   * @param _token Token address to allow/disallow the deposit
   * @param _isDistributable true: distributable false: not distributable
   */
  function updateDistributableTokenAddress(
    uint256 _gid,
    address _token,
    bool _isDistributable
  ) external onlyOwner onlyValidGID(_gid) {
    _updateDistributableTokenAddress(_gid, _token, _isDistributable);
  }

  function _updateDistributableTokenAddress(
    uint256 _gid,
    address _token,
    bool _isDistributable
  ) internal {
    emit DistributableTokenAddressUpdated(msg.sender, _gid, _token, distributable[_gid][_token], _isDistributable);

    // update distributable token list
    if (_isDistributable) {
      if (!distributable[_gid][_token]) {
        // add token to the list only if it's added newly
        distributableTokenList[_gid].push(_token);
      }
    } else {
      for (uint256 i; i < distributableTokenList[_gid].length; i++) {
        if (_token == distributableTokenList[_gid][i]) {
          distributableTokenList[_gid][i] = distributableTokenList[_gid][distributableTokenList[_gid].length - 1];
          distributableTokenList[_gid].pop();
          break;
        }
      }
    }

    // update distributable token amount
    distributable[_gid][_token] = _isDistributable;
  }

  /**
   * @notice Returns the deposit token list of the game
   * @param _gid Game ID
   */
  function getDepositTokenList(uint256 _gid) external view returns (address[] memory) {
    return depositTokenList[_gid];
  }

  /**
   * @notice Returns the distributable token list of the game
   * @param _gid Game ID
   */
  function getDistributableTokenList(uint256 _gid) external view returns (address[] memory) {
    return distributableTokenList[_gid];
  }

  /**
   * @notice Returns the number of games added in games array
   */
  function gameLength() external view returns (uint256) {
    return games.length;
  }
}
