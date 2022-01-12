//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

/**
 * @title TokenRegistry Contract Interface
 * @notice Define the interface used to get the token information
 * @author David Lee
 */
interface IGameRegistry {
  /**
   * @notice Provide the deposit amount of the token given
   * @param _token Token address
   * @return uint256 Deposit amount
   */
  function depositTokenAmount(address _token) external view returns (uint256);
}
