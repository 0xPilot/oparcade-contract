// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "./interfaces/IAddressRegistry.sol";
import "./interfaces/IGameRegistry.sol";

/**
 * @title Oparcade
 * @notice This contract manages token deposit/distribution from/to the users playing the game/tournament
 * @author David Lee
 */
contract Oparcade is
  OwnableUpgradeable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable,
  ERC721HolderUpgradeable,
  ERC1155HolderUpgradeable
{
  using SafeERC20Upgradeable for IERC20Upgradeable;

  event UserDeposited(address by, uint256 indexed gid, uint256 indexed tid, address indexed token, uint256 amount);
  event PrizeDistributed(
    address by,
    address[] winners,
    uint256 indexed gid,
    uint256 indexed tid,
    address indexed token,
    uint256[] amounts
  );
  event NFTPrizeDistributed(
    address by,
    address[] winners,
    uint256 indexed gid,
    uint256 indexed tid,
    address indexed nftAddress,
    uint256 nftType,
    uint256[] tokenIds,
    uint256[] amounts
  );
  event PrizeDeposited(
    address by,
    address depositor,
    uint256 indexed gid,
    uint256 indexed tid,
    address indexed token,
    uint256 amount
  );
  event PrizeWithdrawn(
    address by,
    address to,
    uint256 indexed gid,
    uint256 indexed tid,
    address indexed token,
    uint256 amount
  );
  event NFTPrizeDeposited(
    address by,
    address from,
    uint256 indexed gid,
    uint256 indexed tid,
    address indexed nftAddress,
    uint256 nftType,
    uint256[] tokenIds,
    uint256[] amounts
  );
  event NFTPrizeWithdrawn(
    address by,
    address to,
    uint256 indexed gid,
    uint256 indexed tid,
    address indexed nftAddress,
    uint256 nftType,
    uint256[] tokenIds,
    uint256[] amounts
  );
  event Withdrawn(address indexed by, address indexed beneficiary, address indexed token, uint256 amount);

  bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;

  bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

  /// @dev Game ID -> Tournament ID -> Token Address -> Total User Deposit Amount
  mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public totalUserDeposit;

  /// @dev Game ID -> Tournament ID -> Token Address -> Total Prize Distribution Amount excluding Fee
  mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public totalPrizeDistribution;

  /// @dev Game ID -> Tournament ID -> Token Address -> Total Prize Fee Amount
  mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public totalPrizeFee;

  /// @dev Game ID -> Tournament ID -> NFT Address -> Token ID -> Distribution Amount
  mapping(uint256 => mapping(uint256 => mapping(address => mapping(uint256 => uint256))))
    public totalNFTPrizeDistribution;

  /// @dev Game ID -> Tournament ID -> Token Address -> Total Prize Deposit Amount
  mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public totalPrizeDeposit;

  /// @dev Game ID -> Tournament ID -> NFT Address -> Token ID -> Deposit Amount
  mapping(uint256 => mapping(uint256 => mapping(address => mapping(uint256 => uint256)))) public totalNFTPrizeDeposit;

  /// @dev Token Address -> Total Withdraw Amount
  mapping(address => uint256) public totalWithdrawAmount;

  /// @dev AddressRegistry
  IAddressRegistry public addressRegistry;

  modifier onlyMaintainer() {
    require(msg.sender == addressRegistry.maintainer(), "Only maintainer");
    _;
  }

  function initialize(address _addressRegistry) public initializer {
    __Ownable_init();
    __ReentrancyGuard_init();
    __Pausable_init();
    __ERC721Holder_init();
    __ERC1155Holder_init();

    require(_addressRegistry != address(0), "Invalid AddressRegistry");

    // initialize AddressRegistery
    addressRegistry = IAddressRegistry(_addressRegistry);
  }

  /**
   * @notice Deposit ERC20 tokens from user
   * @dev Only tokens registered in GameRegistry with an amount greater than zero is valid for the deposit
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _token Token address to deposit
   */
  function deposit(
    uint256 _gid,
    uint256 _tid,
    address _token
  ) external whenNotPaused {
    // get token amount to deposit
    uint256 depositTokenAmount = IGameRegistry(addressRegistry.gameRegistry()).depositTokenAmount(_gid, _tid, _token);

    // check if the token address is valid
    require(depositTokenAmount > 0, "Invalid deposit token");

    // transfer the payment
    IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(this), depositTokenAmount);
    totalUserDeposit[_gid][_tid][_token] += depositTokenAmount;

    emit UserDeposited(msg.sender, _gid, _tid, _token, depositTokenAmount);
  }

  /**
   * @notice Distribute winners their prizes
   * @dev Only maintainer
   * @dev The maximum distributable prize amount is the sum of the users' deposit and the prize that the owner deposited
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _winners Winners list
   * @param _token Prize token address
   * @param _amounts Prize list
   */
  function distributePrize(
    uint256 _gid,
    uint256 _tid,
    address[] calldata _winners,
    address _token,
    uint256[] calldata _amounts
  ) external whenNotPaused onlyMaintainer {
    require(_winners.length == _amounts.length, "Mismatched winners and amounts");

    // get gameRegistry
    IGameRegistry gameRegistry = IGameRegistry(addressRegistry.gameRegistry());

    // check if token is allowed to distribute
    require(gameRegistry.distributable(_gid, _token), "Disallowed distribution token");

    _transferPayment(_gid, _tid, _winners, _token, _amounts);

    // check if the prize amount is not exceeded
    require(
      totalPrizeDistribution[_gid][_tid][_token] + totalPrizeFee[_gid][_tid][_token] <=
        totalPrizeDeposit[_gid][_tid][_token] + totalUserDeposit[_gid][_tid][_token],
      "Prize amount exceeded"
    );

    emit PrizeDistributed(msg.sender, _winners, _gid, _tid, _token, _amounts);
  }

  /**
   * @notice Transfer the winners' ERC20 token prizes and relevant fees
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _winners Winners list
   * @param _token Prize token address
   * @param _amounts Prize list
   */
  function _transferPayment(
    uint256 _gid,
    uint256 _tid,
    address[] calldata _winners,
    address _token,
    uint256[] calldata _amounts
  ) internal {
    // get gameRegistry
    IGameRegistry gameRegistry = IGameRegistry(addressRegistry.gameRegistry());

    // transfer the winners their prizes
    uint256 totalPlatformFeeAmount;
    uint256 totalGameCreatorFeeAmount;
    uint256 totalTournamentCreatorFeeAmount;
    for (uint256 i; i < _winners.length; i++) {
      // get userAmount
      uint256 userAmount = _amounts[i];

      {
        // calculate the platform fee
        uint256 platformFeeAmount = (_amounts[i] * IGameRegistry(addressRegistry.gameRegistry()).platformFee()) / 100_0;
        totalPlatformFeeAmount += platformFeeAmount;

        // update userAmount
        userAmount -= platformFeeAmount;
      }

      {
        // calculate gameCreatorFee
        uint256 gameCreatorFee = gameRegistry.appliedGameCreatorFees(_gid, _tid);
        uint256 gameCreatorFeeAmount = (_amounts[i] * gameCreatorFee) / 100_0;
        totalGameCreatorFeeAmount += gameCreatorFeeAmount;

        // update userAmount
        userAmount -= gameCreatorFeeAmount;
      }

      {
        // calculate tournamentCreatorFee
        uint256 tournamentCreatorFee = gameRegistry.tournamentCreatorFees(_gid, _tid);
        uint256 tournamentCreatorFeeAmount = (_amounts[i] * tournamentCreatorFee) / 100_0;
        totalTournamentCreatorFeeAmount += tournamentCreatorFeeAmount;

        // update userAmount
        userAmount -= tournamentCreatorFeeAmount;
      }

      // transfer the prize
      totalPrizeDistribution[_gid][_tid][_token] += userAmount;
      IERC20Upgradeable(_token).safeTransfer(_winners[i], userAmount);
    }

    // transfer the fees
    totalPrizeFee[_gid][_tid][_token] +=
      totalPlatformFeeAmount +
      totalGameCreatorFeeAmount +
      totalTournamentCreatorFeeAmount;
    IERC20Upgradeable(_token).safeTransfer(
      IGameRegistry(addressRegistry.gameRegistry()).feeRecipient(),
      totalPlatformFeeAmount
    );
    IERC20Upgradeable(_token).safeTransfer(gameRegistry.gameCreators(_gid), totalGameCreatorFeeAmount);
    IERC20Upgradeable(_token).safeTransfer(
      gameRegistry.getTournamentCreator(_gid, _tid),
      totalTournamentCreatorFeeAmount
    );
  }

  /**
   * @notice Distribute winners' NFT prizes
   * @dev Only maintainer
   * @dev NFT type should be either 721 or 1155
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _winners Winners list
   * @param _nftAddress NFT address
   * @param _nftType NFT type (721/1155)
   * @param _tokenIds Token Id list
   * @param _amounts Token amount list
   */
  function distributeNFTPrize(
    uint256 _gid,
    uint256 _tid,
    address[] calldata _winners,
    address _nftAddress,
    uint256 _nftType,
    uint256[] calldata _tokenIds,
    uint256[] calldata _amounts
  ) external whenNotPaused nonReentrant onlyMaintainer {
    // check if token is allowed to distribute
    require(
      IGameRegistry(addressRegistry.gameRegistry()).distributable(_gid, _nftAddress),
      "Disallowed distribution token"
    );

    require(_nftType == 721 || _nftType == 1155, "Unexpected NFT type");
    require(
      _winners.length == _tokenIds.length && _tokenIds.length == _amounts.length,
      "Mismatched NFT distribution data"
    );

    uint256 totalAmounts;
    if (_nftType == 721) {
      require(IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721), "Unexpected NFT address");

      // update totalNFTPrizeDeposit and transfer NFTs to the winners
      for (uint256 i; i < _winners.length; i++) {
        require(
          totalNFTPrizeDeposit[_gid][_tid][_nftAddress][_tokenIds[i]] -
            totalNFTPrizeDistribution[_gid][_tid][_nftAddress][_tokenIds[i]] ==
            1,
          "NFT prize distribution amount exceeded"
        );

        totalNFTPrizeDistribution[_gid][_tid][_nftAddress][_tokenIds[i]] = 1;
        totalAmounts += _amounts[i];
        IERC721Upgradeable(_nftAddress).safeTransferFrom(address(this), _winners[i], _tokenIds[i]);
      }

      // check if all amount value is 1
      require(totalAmounts == _winners.length, "Invalid amount value");
    } else {
      require(IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155), "Unexpected NFT address");

      // update totalNFTPrizeDeposit and transfer NFTs to the winners
      for (uint256 i; i < _winners.length; i++) {
        require(
          totalNFTPrizeDeposit[_gid][_tid][_nftAddress][_tokenIds[i]] -
            totalNFTPrizeDistribution[_gid][_tid][_nftAddress][_tokenIds[i]] >=
            _amounts[i],
          "NFT prize distribution amount exceeded"
        );

        totalNFTPrizeDistribution[_gid][_tid][_nftAddress][_tokenIds[i]] += _amounts[i];
        IERC1155Upgradeable(_nftAddress).safeTransferFrom(
          address(this),
          _winners[i],
          _tokenIds[i],
          _amounts[i],
          bytes("")
        );
      }
    }

    emit NFTPrizeDistributed(msg.sender, _winners, _gid, _tid, _nftAddress, _nftType, _tokenIds, _amounts);
  }

  /**
   * @notice Deposit the prize tokens for the specific game/tournament
   * @dev Only tokens which are allowed as a distributable token can be deposited
   * @dev Prize is transferred from _depositor address to this contract
   * @param _depositor Depositor address
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _token Prize token address
   * @param _amount Prize amount to deposit
   */
  function depositPrize(
    address _depositor,
    uint256 _gid,
    uint256 _tid,
    address _token,
    uint256 _amount
  ) external {
    require(msg.sender == owner() || msg.sender == addressRegistry.gameRegistry(), "Only owner or GameRegistry");
    require(_token != address(0), "Unexpected token address");

    // check if tokens are allowed to claim as a prize
    require(IGameRegistry(addressRegistry.gameRegistry()).distributable(_gid, _token), "Disallowed distribution token");

    // deposit prize tokens
    IERC20Upgradeable(_token).safeTransferFrom(_depositor, address(this), _amount);
    totalPrizeDeposit[_gid][_tid][_token] += _amount;

    emit PrizeDeposited(msg.sender, _depositor, _gid, _tid, _token, _amount);
  }

  /**
   * @notice Withdraw the prize tokens from the specific game/tournament
   * @dev Only owner
   * @param _to Beneficiary address
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _token Prize token address
   * @param _amount Prize amount to withdraw
   */
  function withdrawPrize(
    address _to,
    uint256 _gid,
    uint256 _tid,
    address _token,
    uint256 _amount
  ) external onlyOwner {
    // check if the prize is sufficient to withdraw
    require(totalPrizeDeposit[_gid][_tid][_token] >= _amount, "Insufficient prize");

    // withdraw the prize
    totalPrizeDeposit[_gid][_tid][_token] -= _amount;
    IERC20Upgradeable(_token).safeTransfer(_to, _amount);

    emit PrizeWithdrawn(msg.sender, _to, _gid, _tid, _token, _amount);
  }

  /**
   * @notice Deposit NFT prize for the specific game/tournament
   * @dev NFT type should be either 721 or 1155
   * @param _from NFT owner address
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _nftAddress NFT address
   * @param _nftType NFT type (721/1155)
   * @param _tokenIds Token Id list
   * @param _amounts Token amount list
   */
  function depositNFTPrize(
    address _from,
    uint256 _gid,
    uint256 _tid,
    address _nftAddress,
    uint256 _nftType,
    uint256[] calldata _tokenIds,
    uint256[] calldata _amounts
  ) external {
    require(msg.sender == owner() || msg.sender == addressRegistry.gameRegistry(), "Only owner or GameRegistry");

    // check if NFT is allowed to distribute
    require(
      IGameRegistry(addressRegistry.gameRegistry()).distributable(_gid, _nftAddress),
      "Disallowed distribution token"
    );

    require(_nftAddress != address(0), "Unexpected NFT address");
    require(_nftType == 721 || _nftType == 1155, "Unexpected NFT type");
    require(_tokenIds.length == _amounts.length, "Mismatched deposit data");

    uint256 totalAmounts;
    if (_nftType == 721) {
      require(IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721), "Unexpected NFT address");

      // transfer NFTs to the contract and update totalNFTPrizeDeposit
      for (uint256 i; i < _tokenIds.length; i++) {
        IERC721Upgradeable(_nftAddress).safeTransferFrom(_from, address(this), _tokenIds[i]);
        totalNFTPrizeDeposit[_gid][_tid][_nftAddress][_tokenIds[i]] = 1;
        totalAmounts += _amounts[i];
      }

      // check if all amount value is 1
      require(totalAmounts == _tokenIds.length, "Invalid amount value");
    } else {
      require(IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155), "Unexpected NFT address");

      // transfer NFTs to the contract and update totalNFTPrizeDeposit
      IERC1155Upgradeable(_nftAddress).safeBatchTransferFrom(_from, address(this), _tokenIds, _amounts, bytes(""));
      for (uint256 i; i < _tokenIds.length; i++) {
        totalNFTPrizeDeposit[_gid][_tid][_nftAddress][_tokenIds[i]] += _amounts[i];
      }
    }

    emit NFTPrizeDeposited(msg.sender, _from, _gid, _tid, _nftAddress, _nftType, _tokenIds, _amounts);
  }

  /**
   * @notice Withdraw NFT prize for the specific game/tournament
   * @dev Only owner
   * @dev NFT type should be either 721 or 1155
   * @param _to NFT receiver address
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _nftAddress NFT address
   * @param _nftType NFT type (721/1155)
   * @param _tokenIds Token Id list
   * @param _amounts Token amount list
   */
  function withdrawNFTPrize(
    address _to,
    uint256 _gid,
    uint256 _tid,
    address _nftAddress,
    uint256 _nftType,
    uint256[] calldata _tokenIds,
    uint256[] calldata _amounts
  ) external nonReentrant onlyOwner {
    require(_nftType == 721 || _nftType == 1155, "Unexpected NFT type");
    require(_tokenIds.length == _amounts.length, "Mismatched deposit data");

    uint256 totalAmounts;
    if (_nftType == 721) {
      require(IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721), "Unexpected NFT address");

      // update totalNFTPrizeDeposit and transfer NFTs from the contract
      for (uint256 i; i < _tokenIds.length; i++) {
        require(
          totalNFTPrizeDeposit[_gid][_tid][_nftAddress][_tokenIds[i]] -
            totalNFTPrizeDistribution[_gid][_tid][_nftAddress][_tokenIds[i]] ==
            1,
          "Insufficient NFT prize"
        );

        totalNFTPrizeDeposit[_gid][_tid][_nftAddress][_tokenIds[i]] = 0;
        totalAmounts += _amounts[i];
        IERC721Upgradeable(_nftAddress).safeTransferFrom(address(this), _to, _tokenIds[i]);
      }

      // check if all amount value is 1
      require(totalAmounts == _tokenIds.length, "Invalid amount value");
    } else {
      require(IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155), "Unexpected NFT address");

      // update totalNFTPrizeDeposit and transfer NFTs from the contract
      for (uint256 i; i < _tokenIds.length; i++) {
        require(
          totalNFTPrizeDeposit[_gid][_tid][_nftAddress][_tokenIds[i]] -
            totalNFTPrizeDistribution[_gid][_tid][_nftAddress][_tokenIds[i]] >=
            _amounts[i],
          "Insufficient NFT prize"
        );

        totalNFTPrizeDeposit[_gid][_tid][_nftAddress][_tokenIds[i]] -= _amounts[i];
      }
      IERC1155Upgradeable(_nftAddress).safeBatchTransferFrom(address(this), _to, _tokenIds, _amounts, bytes(""));
    }

    emit NFTPrizeWithdrawn(msg.sender, _to, _gid, _tid, _nftAddress, _nftType, _tokenIds, _amounts);
  }

  /**
   * @notice Withdraw tokens
   * @dev Only owner
   * @param _tokens Token addresses
   * @param _amounts Token amounts
   * @param _beneficiary Beneficiary address
   */
  function withdraw(
    address[] calldata _tokens,
    uint256[] calldata _amounts,
    address _beneficiary
  ) external onlyOwner {
    require(_tokens.length == _amounts.length, "Mismatched withdrawal data");

    for (uint256 i; i < _tokens.length; i++) {
      totalWithdrawAmount[_tokens[i]] += _amounts[i];
      IERC20Upgradeable(_tokens[i]).safeTransfer(_beneficiary, _amounts[i]);

      emit Withdrawn(msg.sender, _beneficiary, _tokens[i], _amounts[i]);
    }
  }

  /**
   * @notice Pause Oparcade
   * @dev Only owner
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @notice Resume Oparcade
   * @dev Only owner
   */
  function unpause() external onlyOwner {
    _unpause();
  }
}
