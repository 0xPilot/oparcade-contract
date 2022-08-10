// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

/**
 * @title GameRegistry Contract Interface
 * @notice Define the interface necessary for the GameRegistry
 * @author David Lee
 */
interface IGameRegistry {
  /**
   * @notice Returns the game creator address of the game
   * @param _gid Game ID created
   * @return (address) Game creator address of the game
   */
  function gameCreators(uint256 _gid) external view returns (address);

  /**
   * @notice Returns the game creator fee applied
   * @dev Either base game creator fee set by the owner or one proposed by the tournament creator is applied
   * @dev The game creator fee applied can't be less than the base one
   * @param _gid Game ID
   * @param _tid Tournanemnt ID
   * @return (uint256) Game creator fee applied to the tournament
   */
  function appliedGameCreatorFees(uint256 _gid, uint256 _tid) external view returns (uint256);

  /**
   * @notice Returns the tournament creator fee percentage of the specific game/tournament
   * @dev Max value is 1000 (100%)
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @return (uint256) Tournament creator fee percentage
   */
  function tournamentCreatorFees(uint256 _gid, uint256 _tid) external view returns (uint256);

  /**
   * @notice Returns the deposit amount of the token given
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @param _token Token address
   * @return (uint256) Deposit amount
   */
  function depositTokenAmount(
    uint256 _gid,
    uint256 _tid,
    address _token
  ) external view returns (uint256);

  /**
   * @notice Returns the claimability of the token given
   * @param _gid Game ID
   * @param _token Token address
   * @return (bool) true: distributable, false: not distributable
   */
  function distributable(uint256 _gid, address _token) external view returns (bool);

  /**
   * @notice Returns whether the game is deprecated or not
   * @param _gid Game ID
   * @return (bool) true: deprecated, false: not deprecated
   */
  function isDeprecatedGame(uint256 _gid) external view returns (bool);

  /**
   * @notice Returns the number of games added in games array
   * @return (uint256) Game count
   */
  function gameCount() external view returns (uint256);

  /**
   * @notice Returns the tournament creator addresses of the specific game
   * @param _gid Game ID
   * @param _tid Tournament ID
   * @return (address) Tournament creator address
   */
  function getTournamentCreator(uint256 _gid, uint256 _tid) external view returns (address);

  /**
   * @notice Returns the Oparcade platform fee
   * @dev Max value is 1000 (100%)
   * @return (uint256) Oparcade platform fee
   */
  function platformFee() external view returns (uint256);

  /**
   * @notice Returns the fee recipient address
   * @return (address) Fee recipient address
   */
  function feeRecipient() external view returns (address);
}
