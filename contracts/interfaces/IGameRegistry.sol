// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title GameRegistry Contract Interface
 * @notice Define the interface used to get the game and tournament information
 * @author David Lee
 */
interface IGameRegistry {
  function gameCreators(uint256 _gid) external view returns (address);

  function appliedGameCreatorFees(uint256 _gid, uint256 _tid) external view returns (uint256);

  function tournamentCreators(uint256 _gid) external view returns (address[] memory);

  function tournamentCreatorFees(uint256 _gid, uint256 _tid) external view returns (uint256);

  /**
   * @notice Provide the deposit amount of the token given
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _token Token address
   * @return uint256 Deposit amount
   */
  function depositTokenAmount(
    uint256 _gid,
    uint256 _tid,
    address _token
  ) external view returns (uint256);

  /**
   * @notice Provide the claimability of the token given
   * @param _gid Game ID
   * @param _token Token address
   * @return bool true: distributable, false: not distributable
   */
  function distributable(uint256 _gid, address _token) external view returns (bool);

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

  /**
   * @notice Provide the Oparcade platform fee
   * @dev Max value is 1000 (100%)
   * @return uint256 Oparcade platform fee
   */
  function platformFee() external view returns (uint256);

  function feeRecipient() external view returns (address);
}
