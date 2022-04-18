// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "./interfaces/IAddressRegistry.sol";
import "./interfaces/IGameRegistry.sol";

/**
 * @title Oparcade
 * @notice This manages the token deposit/distribution from/to the users
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
  event Withdrawn(address indexed by, address indexed token, uint256 amount);
  event PrizeDeposited(address by, uint256 indexed gid, uint256 indexed tid, address indexed token, uint256 amount);
  event PrizeWithdrawn(address by, uint256 indexed gid, uint256 indexed tid, address indexed token, uint256 amount);
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
  event PrizeDistributed(
    address by,
    address winner,
    uint256 indexed gid,
    uint256 indexed tid,
    address indexed token,
    uint256 amount
  );
  event NFTPrizeDistributed(
    address by,
    address winner,
    uint256 indexed gid,
    uint256 indexed tid,
    address indexed nftAddress,
    uint256 nftType,
    uint256 tokenId,
    uint256 amount
  );
  event PlatformFeeUpdated(
    address indexed by,
    address indexed oldFeeRecipient,
    uint256 oldPlatformFee,
    address indexed newFeeRecipient,
    uint256 newPlatformFee
  );

  bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;

  bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

  /// @dev Game ID -> Tournament ID -> Token Address -> Total User Deposit Amount
  mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public totalUserDeposit;

  /// @dev Token Address -> Total Withdraw Amount
  mapping(address => uint256) public totalWithdrawAmount;

  /// @dev Game ID -> Tournament ID -> Token Address -> Total Prize Deposit Amount
  mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public totalPrizeDeposit;

  /// @dev Game ID -> Tournament ID -> Token Address -> Total Prize Distribution Amount excluding Fee
  mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public totalPrizeDistribution;

  /// @dev Game ID -> Tournament ID -> Token Address -> Total Prize Fee Amount
  mapping(uint256 => mapping(uint256 => mapping(address => uint256))) public totalPrizeFee;

  /// @dev Game ID -> Tournament ID -> NFT Address -> Token ID -> Deposit Amount
  mapping(uint256 => mapping(uint256 => mapping(address => mapping(uint256 => uint256)))) public totalNFTPrizeDeposit;

  /// @dev Game ID -> Tournament ID -> NFT Address -> Token ID -> Distribution Amount
  mapping(uint256 => mapping(uint256 => mapping(address => mapping(uint256 => uint256))))
    public totalNFTPrizeDistribution;

  /// @dev AddressRegistry
  IAddressRegistry public addressRegistry;

  /// @dev Platform fee
  uint16 public platformFee;

  /// @dev Platform fee recipient
  address public feeRecipient;

  modifier onlyMaintainer() {
    require(msg.sender == addressRegistry.maintainer(), "Only maintainer");
    _;
  }

  receive() external payable {}

  function initialize(
    address _addressRegistry,
    address _feeRecipient,
    uint16 _platformFee
  ) public initializer {
    __Ownable_init();
    __ReentrancyGuard_init();
    __Pausable_init();
    __ERC721Holder_init();
    __ERC1155Holder_init();

    require(_addressRegistry != address(0), "Invalid AddressRegistry");
    require(_feeRecipient != address(0) || _platformFee == 0, "Fee recipient not set");
    require(_platformFee <= 1000, "Platform fee exceeded");

    // initialize AddressRegistery
    addressRegistry = IAddressRegistry(_addressRegistry);

    // initialize fee and recipient
    feeRecipient = _feeRecipient;
    platformFee = _platformFee;
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
    uint256 depositTokenAmount = IGameRegistry(addressRegistry.gameRegistry()).depositTokenAmount(_gid, _token);

    // check if the token address is valid
    require(depositTokenAmount > 0, "Invalid deposit token");

    // transfer the payment
    IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(this), depositTokenAmount);
    totalUserDeposit[_gid][_tid][_token] += depositTokenAmount;

    emit UserDeposited(msg.sender, _gid, _tid, _token, depositTokenAmount);
  }

  /**
   * @notice Withdraw tokens
   * @dev Only owner
   * @param _tokens Token addresses
   * @param _amounts Token amounts
   * @param _beneficiary Beneficiary address
   */
  function withdraw(
    address[] memory _tokens,
    uint256[] memory _amounts,
    address _beneficiary
  ) external onlyOwner {
    require(_tokens.length == _amounts.length, "Mismatched withdrawal data");

    for (uint256 i; i < _tokens.length; i++) {
      IERC20Upgradeable(_tokens[i]).safeTransfer(_beneficiary, _amounts[i]);
      totalWithdrawAmount[_tokens[i]] += _amounts[i];

      emit Withdrawn(msg.sender, _tokens[i], _amounts[i]);
    }
  }

  /**
   * @notice Deposit the prize tokens for the specific game/tournament
   * @dev Only owner
   * @dev Only tokens which are allowed as a distributable token can be deposited
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _token Prize token address
   * @param _amount Prize amount to deposit
   */
  function depositPrize(
    uint256 _gid,
    uint256 _tid,
    address _token,
    uint256 _amount
  ) external onlyOwner {
    // check if tokens are allowed to claim as a prize
    require(IGameRegistry(addressRegistry.gameRegistry()).distributable(_gid, _token), "Disallowed distribution token");

    // deposit prize tokens
    IERC20Upgradeable(_token).safeTransferFrom(msg.sender, address(this), _amount);
    totalPrizeDeposit[_gid][_tid][_token] += _amount;

    emit PrizeDeposited(msg.sender, _gid, _tid, _token, _amount);
  }

  /**
   * @notice Withdraw the prize tokens from the specific game/tournament
   * @dev Only owner
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _token Prize token address
   */
  function withdrawPrize(
    uint256 _gid,
    uint256 _tid,
    address _token,
    uint256 _amount
  ) external onlyOwner {
    // check if the prize is sufficient to withdraw
    require(totalPrizeDeposit[_gid][_tid][_token] >= _amount, "Insufficient prize");

    // withdraw the prize
    IERC20Upgradeable(_token).safeTransfer(msg.sender, _amount);
    totalUserDeposit[_gid][_tid][_token] -= _amount;

    emit PrizeWithdrawn(msg.sender, _gid, _tid, _token, _amount);
  }

  /**
   * @notice Deposit NFT prize for the specific game/tournament
   * @dev Only owner
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
    uint256[] memory _tokenIds,
    uint256[] memory _amounts
  ) external onlyOwner {
    // check if NFT is allowed to distribute
    require(
      IGameRegistry(addressRegistry.gameRegistry()).distributable(_gid, _nftAddress),
      "Disallowed distribution token"
    );

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
    uint256[] memory _tokenIds,
    uint256[] memory _amounts
  ) external nonReentrant onlyOwner {
    require(_nftType == 721 || _nftType == 1155, "Unexpected NFT type");
    require(_tokenIds.length == _amounts.length, "Mismatched deposit data");

    uint256 totalAmounts;
    if (_nftType == 721) {
      require(IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC721), "Unexpected NFT address");

      // transfer NFTs to the contract and update totalNFTPrizeDeposit
      for (uint256 i; i < _tokenIds.length; i++) {
        IERC721Upgradeable(_nftAddress).safeTransferFrom(address(this), _to, _tokenIds[i]);
        totalNFTPrizeDeposit[_gid][_tid][_nftAddress][_tokenIds[i]] = 0;
        totalAmounts += _amounts[i];
      }

      // check if all amount value is 1
      require(totalAmounts == _tokenIds.length, "Invalid amount value");
    } else {
      require(IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155), "Unexpected NFT address");

      // transfer NFTs to the contract and update totalNFTPrizeDeposit
      IERC1155Upgradeable(_nftAddress).safeBatchTransferFrom(address(this), _to, _tokenIds, _amounts, bytes(""));
      for (uint256 i; i < _tokenIds.length; i++) {
        require(totalNFTPrizeDeposit[_gid][_tid][_nftAddress][_tokenIds[i]] >= _amounts[i], "Insufficient NFT prize");

        totalNFTPrizeDeposit[_gid][_tid][_nftAddress][_tokenIds[i]] -= _amounts[i];
      }
    }

    emit NFTPrizeWithdrawn(msg.sender, _to, _gid, _tid, _nftAddress, _nftType, _tokenIds, _amounts);
  }

  /**
   * @notice Distribute winners their prizes
   * @dev Only maintainer
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _winners Winners list
   * @param _token Prize token address
   * @param _amounts Prize list
   */
  function distributePrize(
    uint256 _gid,
    uint256 _tid,
    address[] memory _winners,
    address _token,
    uint256[] memory _amounts
  ) external whenNotPaused onlyMaintainer {
    require(_winners.length == _amounts.length, "Mismatched winners and amounts");

    // check if token is allowed to distribute
    require(IGameRegistry(addressRegistry.gameRegistry()).distributable(_gid, _token), "Disallowed distribution token");

    // transfer the payment
    for (uint256 i; i < _winners.length; i++) {
      // calculate the fee
      uint256 feeAmount = (_amounts[i] * platformFee) / 1000;
      uint256 userAmount = _amounts[i] - feeAmount;

      // transfer the prize and fee
      IERC20Upgradeable(_token).safeTransfer(feeRecipient, feeAmount);
      IERC20Upgradeable(_token).safeTransfer(_winners[i], userAmount);
      totalPrizeFee[_gid][_tid][_token] += feeAmount;
      totalPrizeDistribution[_gid][_tid][_token] += userAmount;

      emit PrizeDistributed(msg.sender, _winners[i], _gid, _tid, _token, userAmount);
    }

    // check if the prize amount is not exceeded
    require(
      totalPrizeDistribution[_gid][_tid][_token] + totalPrizeFee[_gid][_tid][_token] <=
        totalPrizeDeposit[_gid][_tid][_token],
      "Prize amount exceeded"
    );
  }

  /**
   * @notice Distribute winners NFT prizes
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
    address[] memory _winners,
    address _nftAddress,
    uint256 _nftType,
    uint256[] memory _tokenIds,
    uint256[] memory _amounts
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

      // transfer NFTs to the contract and update totalNFTPrizeDeposit
      for (uint256 i; i < _winners.length; i++) {
        require(totalNFTPrizeDistribution[_gid][_tid][_nftAddress][_tokenIds[i]] == 1, "NFT prize amount exceeded");

        IERC721Upgradeable(_nftAddress).safeTransferFrom(address(this), _winners[i], _tokenIds[i]);
        totalNFTPrizeDistribution[_gid][_tid][_nftAddress][_tokenIds[i]] = 0;
        totalAmounts += _amounts[i];

        emit NFTPrizeDistributed(msg.sender, _winners[i], _gid, _tid, _nftAddress, _nftType, _tokenIds[i], _amounts[i]);
      }

      // check if all amount value is 1
      require(totalAmounts == _winners.length, "Invalid amount value");
    } else {
      require(IERC165(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155), "Unexpected NFT address");

      // transfer NFTs to the contract and update totalNFTPrizeDeposit
      for (uint256 i; i < _winners.length; i++) {
        require(
          totalNFTPrizeDeposit[_gid][_tid][_nftAddress][_tokenIds[i]] >= _amounts[i],
          "NFT prize amount exceeded"
        );

        IERC1155Upgradeable(_nftAddress).safeTransferFrom(
          address(this),
          _winners[i],
          _tokenIds[i],
          _amounts[i],
          bytes("")
        );
        totalNFTPrizeDeposit[_gid][_tid][_nftAddress][_tokenIds[i]] -= _amounts[i];

        emit NFTPrizeDistributed(msg.sender, _winners[i], _gid, _tid, _nftAddress, _nftType, _tokenIds[i], _amounts[i]);
      }
    }
  }

  /**
   * @notice Update platform fee
   * @dev Only owner
   * @dev Allow zero recipient address only of fee is also zero
   * @param _platformFee platform fee
   */
  function updatePlatformFee(address _feeRecipient, uint16 _platformFee) external onlyOwner {
    require(_feeRecipient != address(0) || _platformFee == 0, "Fee recipient not set");
    require(_platformFee <= 1000, "Platform fee exceeded");

    emit PlatformFeeUpdated(msg.sender, feeRecipient, platformFee, _feeRecipient, _platformFee);

    feeRecipient = _feeRecipient;
    platformFee = _platformFee;
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
