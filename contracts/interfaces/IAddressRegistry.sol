//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IAddressRegistry {
  function oparcade() external view returns (address);

  function tokenRegistry() external view returns (address);

  function maintainer() external view returns (address);
}
