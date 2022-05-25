// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Oparcade Contract Interface
 * @notice Define the interface used to get the token deposit and withdrawal info
 * @author David Lee
 */
interface IOparcade {
  /**
   * @notice Provide the Oparcade platform fee
   * @dev Max value is 1000 (100%)
   * @return uint256 Oparcade platform fee
   */
  function platformFee() external view returns (uint256);

  function depositPrize(
    uint256 _gid,
    uint256 _tid,
    address _token,
    uint256 _amount
  ) external;
}
