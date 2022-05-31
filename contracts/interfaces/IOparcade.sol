// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Oparcade Contract Interface
 * @notice Define the interface used to get the token deposit and withdrawal info
 * @author David Lee
 */
interface IOparcade {
  function depositPrize(
    uint256 _gid,
    uint256 _tid,
    address _token,
    uint256 _amount
  ) external;

  function depositNFTPrize(
    address _from,
    uint256 _gid,
    uint256 _tid,
    address _nftAddress,
    uint256 _nftType,
    uint256[] memory _tokenIds,
    uint256[] memory _amounts
  ) external;
}
