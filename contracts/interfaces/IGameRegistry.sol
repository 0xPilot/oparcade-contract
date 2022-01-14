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
   * @param _gid Game ID
   * @param _token Token address
   * @return uint256 Deposit amount
   */
  function depositAmount(uint256 _gid, address _token) external view returns (uint256);

  /**
   * @notice Provide the claimability of the token given
   * @param _gid Game ID
   * @param _token Token address
   * @return bool true: claimable, false: not claimable
   */
  function claimable(uint256 _gid, address _token) external view returns (bool);

  /**
   * @notice Provide whether the game is deprecated or not
   * @param _gid Game ID
   * @return bool true: deprecated, false: not deprecated
   */
  function isDeprecatedGame(uint256 _gid) external view returns (bool);

  /**
   * @notice Returns the number of games added in games array
   */
  function gameLength() external view returns (uint256);
}
