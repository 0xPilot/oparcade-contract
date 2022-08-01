// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/IAddressRegistry.sol";
import "./interfaces/IOparcade.sol";

/**
 * @title GameRegistry
 * @notice This contract stores all info related to the game and tournament creation
 * @author David Lee
 */
contract GameRegistry is OwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  struct Token {
    address tokenAddress;
    uint256 tokenAmount;
  }

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
    string tournamentName,
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
  event PlatformFeeUpdated(
    address indexed by,
    address indexed oldFeeRecipient,
    uint256 oldPlatformFee,
    address indexed newFeeRecipient,
    uint256 newPlatformFee
  );
  event TournamentCreationFeeUpdated(
    address indexed by,
    address indexed oldTournamentCreationFeeToken,
    uint256 oldTournamentCreationFeeAmount,
    address indexed newTournamentCreationFeeToken,
    uint256 newTournamentCreationFeeAmount
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

  /// @dev Game ID -> Tournament ID -> Tournament name
  mapping(uint256 => mapping(uint256 => string)) public tournamentNames;

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

  /// @dev Platform fee recipient
  address public feeRecipient;

  /// @dev Platform fee
  uint256 public platformFee;

  /// @dev Tournament creation fee token address
  address public tournamentCreationFeeToken;

  /// @dev Tournament creation fee token amount
  uint256 public tournamentCreationFeeAmount;

  modifier onlyValidGID(uint256 _gid) {
    require(_gid < games.length && !isDeprecatedGame[_gid], "Invalid game index");
    _;
  }

  modifier onlyValidTID(uint256 _gid, uint256 _tid) {
    require(_tid < tournamentCreators[_gid].length, "Invalid tournament index");
    _;
  }

  function initialize(
    address _addressRegistry,
    address _feeRecipient,
    uint256 _platformFee,
    address _tournamentCreationFeeToken,
    uint256 _tournamentCreationFeeAmount
  ) public initializer {
    __Ownable_init();

    require(_feeRecipient != address(0) || _platformFee == 0, "Fee recipient not set");
    require(_platformFee <= 100_0, "Platform fee exceeded");

    // initialize AddressRegistery
    addressRegistry = IAddressRegistry(_addressRegistry);

    // initialize fee and recipient
    feeRecipient = _feeRecipient;
    platformFee = _platformFee;
    tournamentCreationFeeToken = _tournamentCreationFeeToken;
    tournamentCreationFeeAmount = _tournamentCreationFeeAmount;
  }

  /**
   * @notice Add the new game
   * @dev Base game creator fee is the minimum fee vaule that the game creator should be rewarded from the tournamnet of the game
   * @dev When creating the tournament of the game, the game creator fee can be proposed by the tournament creator
   * @dev but the proposed value can't be less than the base one
   * @dev If the proposed game creator fee is 0, the base game creator fee will be applied
   * @param _gameName Game name to add
   * @param _gameCreator Game creator address
   * @param _baseGameCreatorFee Base game creator fee
   */
  function addGame(
    string calldata _gameName,
    address _gameCreator,
    uint256 _baseGameCreatorFee
  ) external onlyOwner returns (uint256 gid) {
    require(bytes(_gameName).length != 0, "Empty game name");
    require(_gameCreator != address(0), "Zero game creator address");
    require(platformFee + _baseGameCreatorFee < 100_0, "Exceeded base game creator fee");

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

  /**
   * @notice Update the game creator
   * @param _gid Game ID
   * @param _gameCreator Game creator address
   */
  function updateGameCreator(uint256 _gid, address _gameCreator) external onlyValidGID(_gid) {
    require(msg.sender == gameCreators[_gid], "Only game creator");
    require(_gameCreator != address(0), "Zero game creator address");

    emit GameCreatorUpdated(msg.sender, _gid, gameCreators[_gid], _gameCreator);

    // update the game creator address
    gameCreators[_gid] = _gameCreator;
  }

  /**
   * @notice Update the base game creator fee
   * @dev Tournament creator fee is the royality that will be transferred to the tournament creator address
   * @dev Tournament creator can propose the game creator fee when creating the tournament
   * @dev but it can't be less than the base game creator fee
   * @param _gid Game ID
   * @param _baseGameCreatorFee Base game creator fee
   */
  function updateBaseGameCreatorFee(uint256 _gid, uint256 _baseGameCreatorFee) external onlyOwner onlyValidGID(_gid) {
    require(platformFee + _baseGameCreatorFee < 100_0, "Exceeded game creator fee");

    emit BaseGameCreatorFeeUpdated(msg.sender, _gid, baseGameCreatorFees[_gid], _baseGameCreatorFee);

    // update the game creator fee
    baseGameCreatorFees[_gid] = _baseGameCreatorFee;
  }

  /**
   * @notice Create the tournament and set tokens
   * @dev Only owner
   * @dev If the proposed game creaetor fee is 0, the base game creator fee is applied
   * @dev The prize pool for the tournament that the owner created is initialized on Oparcade contract
   * @param _gid Game ID
   * @param _proposedGameCreatorFee Proposed game creator fee
   * @param _tournamentCreatorFee Tournament creator fee
   * @param _depositToken Token to allow/disallow the deposit
   * @param _distributionTokenAddress Distribution token address to be set to active
   * @return tid Tournament ID created
   */
  function createTournamentByDAOWithTokens(
    uint256 _gid,
    string memory _tournamentName,
    uint256 _proposedGameCreatorFee,
    uint256 _tournamentCreatorFee,
    Token calldata _depositToken,
    address _distributionTokenAddress
  ) external onlyOwner onlyValidGID(_gid) returns (uint256 tid) {
    // create the tournament
    tid = _createTournament(_gid, _tournamentName, _proposedGameCreatorFee, _tournamentCreatorFee);

    // set the deposit token address and amount
    _updateDepositTokenAmount(_gid, tid, _depositToken.tokenAddress, _depositToken.tokenAmount);

    // set the distributable token address
    if (!distributable[_gid][_distributionTokenAddress]) {
      _updateDistributableTokenAddress(_gid, _distributionTokenAddress, true);
    }

    return tid;
  }

  /**
   * @notice Create the tournament
   * @dev Only owner
   * @dev If the proposed game creaetor fee is 0, the base game creator fee is applied
   * @dev The prize pool for the tournament that the owner created is initialized on Oparcade contract
   * @param _gid Game ID
   * @param _proposedGameCreatorFee Proposed game creator fee
   * @param _tournamentCreatorFee Tournament creator fee
   * @return tid Tournament ID created
   */
  function createTournamentByDAO(
    uint256 _gid,
    string calldata _tournamentName,
    uint256 _proposedGameCreatorFee,
    uint256 _tournamentCreatorFee
  ) external onlyOwner onlyValidGID(_gid) returns (uint256 tid) {
    tid = _createTournament(_gid, _tournamentName, _proposedGameCreatorFee, _tournamentCreatorFee);
  }

  /**
   * @notice Create the tournament
   * @dev If the proposed game creaetor fee is 0, the base game creator fee is applied
   * @param _gid Game ID
   * @param _proposedGameCreatorFee Proposed game creator fee
   * @param _tournamentCreatorFee Tournament creator fee
   * @return tid Tournament ID created
   */
  function _createTournament(
    uint256 _gid,
    string memory _tournamentName,
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
    require(baseGameCreatorFees[_gid] <= appliedGameCreatorFee, "Low game creator fee proposed");
    require(platformFee + appliedGameCreatorFee + _tournamentCreatorFee < 100_0, "Exceeded fees");

    // get the new tournament ID
    tid = tournamentCreators[_gid].length;

    // add the tournament name
    tournamentNames[_gid][tid] = _tournamentName;

    // add the tournament creator address and fee
    tournamentCreators[_gid].push(msg.sender);
    appliedGameCreatorFees[_gid][tid] = appliedGameCreatorFee;
    tournamentCreatorFees[_gid][tid] = _tournamentCreatorFee;

    emit TournamentCreated(msg.sender, _gid, tid, _tournamentName, appliedGameCreatorFee, _tournamentCreatorFee);
  }

  /**
   * @notice Create the tournament
   * @dev Anyone can create the tournament and initialize the prize pool with tokens and NFTs
   * @dev Tournament creator should set all params necessary for the tournament in 1 tx and
   * @dev the params set is immutable. It will be prevent the fraud tournament is created
   * @dev Tournament creator should pay fees to create the tournament
   * @dev and the fee token address and fee token amount are set by the owner
   * @dev If the proposed game creaetor fee is 0, the base game creator fee is applied
   * @dev NFT type to initialize the prize pool should be either 721 or 1155
   * @param _gid Game ID
   * @param _proposedGameCreatorFee Proposed game creator fee
   * @param _tournamentCreatorFee Tournament creator fee
   * @param _depositToken Deposit token (address and amount) for playing the tournament
   * @param _tokenToAddPrizePool Token (address and amount) to initialize the prize pool
   * @param _nftAddressToAddPrizePool NFT address to initialize the prize pool
   * @param _nftTypeToAddPrizePool NFT type to initialize the prize pool
   * @param _tokenIdsToAddPrizePool NFT token Id list to initialize the prize pool
   * @param _amountsToAddPrizePool NFT token amount list to initialize the prize pool
   * @return tid Tournament ID created
   */
  function createTournamentByUser(
    uint256 _gid,
    string calldata _tournamentName,
    uint256 _proposedGameCreatorFee,
    uint256 _tournamentCreatorFee,
    Token calldata _depositToken,
    Token calldata _tokenToAddPrizePool,
    address _nftAddressToAddPrizePool,
    uint256 _nftTypeToAddPrizePool,
    uint256[] memory _tokenIdsToAddPrizePool,
    uint256[] memory _amountsToAddPrizePool
  ) external onlyValidGID(_gid) returns (uint256 tid) {
    // pay the tournament creation fee
    IERC20Upgradeable(tournamentCreationFeeToken).safeTransferFrom(
      msg.sender,
      feeRecipient,
      tournamentCreationFeeAmount
    );

    // create new tournament
    tid = _createTournament(_gid, _tournamentName, _proposedGameCreatorFee, _tournamentCreatorFee);

    // set the deposit token amount
    _updateDepositTokenAmount(_gid, tid, _depositToken.tokenAddress, _depositToken.tokenAmount);

    // set the distributable token
    if (!distributable[_gid][_depositToken.tokenAddress] && _depositToken.tokenAmount > 0) {
      _updateDistributableTokenAddress(_gid, _depositToken.tokenAddress, true);
    }
    if (!distributable[_gid][_tokenToAddPrizePool.tokenAddress] && _tokenToAddPrizePool.tokenAmount > 0) {
      _updateDistributableTokenAddress(_gid, _tokenToAddPrizePool.tokenAddress, true);
    }
    if (!distributable[_gid][_nftAddressToAddPrizePool] && _amountsToAddPrizePool.length > 0) {
      _updateDistributableTokenAddress(_gid, _nftAddressToAddPrizePool, true);
    }

    // initialize the prize pool with tokens
    if (_tokenToAddPrizePool.tokenAmount > 0) {
      IOparcade(addressRegistry.oparcade()).depositPrize(
        msg.sender,
        _gid,
        tid,
        _tokenToAddPrizePool.tokenAddress,
        _tokenToAddPrizePool.tokenAmount
      );
    }

    // initialize the prize pool with NFTs
    if (_nftTypeToAddPrizePool == 721 || _nftTypeToAddPrizePool == 1155) {
      IOparcade(addressRegistry.oparcade()).depositNFTPrize(
        msg.sender,
        _gid,
        tid,
        _nftAddressToAddPrizePool,
        _nftTypeToAddPrizePool,
        _tokenIdsToAddPrizePool,
        _amountsToAddPrizePool
      );
    }
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

  /**
   * @notice Update deposit token amount
   * @dev Only tokens with an amount greater than zero is valid for the deposit
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _token Token address to allow/disallow the deposit
   * @param _amount Token amount
   */
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

  /**
   * @notice Update distributable token address
   * @dev Only owner
   * @param _gid Game ID
   * @param _token Token address to allow/disallow the deposit
   * @param _isDistributable true: distributable false: not distributable
   */
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
   * @return (address[]) Deposit token list of the game
   */
  function getDepositTokenList(uint256 _gid) external view returns (address[] memory) {
    return depositTokenList[_gid];
  }

  /**
   * @notice Returns the distributable token list of the game
   * @param _gid Game ID
   * @param (address[]) Distributable token list of the game
   */
  function getDistributableTokenList(uint256 _gid) external view returns (address[] memory) {
    return distributableTokenList[_gid];
  }

  /**
   * @notice Returns the number of games added in games array
   * @return (uint256) Game count created
   */
  function gameCount() external view returns (uint256) {
    return games.length;
  }

  /**
   * @notice Returns the number of the tournaments of the specific game
   * @param _gid Game ID
   * @return (uint256) Number of the tournament
   */
  function getTournamentCount(uint256 _gid) external view onlyValidGID(_gid) returns (uint256) {
    return tournamentCreators[_gid].length;
  }

  /**
   * @notice Returns the tournament creator address of the specific game/tournament
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @return (address) Tournament creator address
   */
  function getTournamentCreator(uint256 _gid, uint256 _tid)
    external
    view
    onlyValidGID(_gid)
    onlyValidTID(_gid, _tid)
    returns (address)
  {
    return tournamentCreators[_gid][_tid];
  }

  /**
   * @notice Update the platform fee
   * @dev Only owner
   * @dev Allow zero recipient address only of fee is also zero
   * @param _feeRecipient Platform fee recipient address
   * @param _platformFee platform fee
   */
  function updatePlatformFee(address _feeRecipient, uint256 _platformFee) external onlyOwner {
    require(_feeRecipient != address(0) || _platformFee == 0, "Fee recipient not set");
    require(_platformFee <= 100_0, "Platform fee exceeded");

    emit PlatformFeeUpdated(msg.sender, feeRecipient, platformFee, _feeRecipient, _platformFee);

    feeRecipient = _feeRecipient;
    platformFee = _platformFee;
  }

  /**
   * @notice Update the tournament creation fee
   * @dev Only owner
   * @dev Tournament creator should pay this fee when creating the tournament
   * @param _tournamentCreationFeeToken Fee token address
   * @param _tournamentCreationFeeAmount Fee token amount
   */
  function updateTournamentCreationFee(address _tournamentCreationFeeToken, uint256 _tournamentCreationFeeAmount)
    external
    onlyOwner
  {
    require(_tournamentCreationFeeToken != address(0), "Zero tournament creation fee token");
    require(_tournamentCreationFeeAmount > 0, "Zero tournament creation fee");

    emit TournamentCreationFeeUpdated(
      msg.sender,
      tournamentCreationFeeToken,
      tournamentCreationFeeAmount,
      _tournamentCreationFeeToken,
      _tournamentCreationFeeAmount
    );

    tournamentCreationFeeToken = _tournamentCreationFeeToken;
    tournamentCreationFeeAmount = _tournamentCreationFeeAmount;
  }
}
