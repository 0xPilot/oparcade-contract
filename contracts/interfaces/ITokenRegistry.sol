//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ITokenRegistry {
  function depositTokenAmount(address _token) external view returns (uint256);
}
