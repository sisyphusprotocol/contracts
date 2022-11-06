//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

interface IRenderer {
  function renderTokenById(uint256 id) external view returns (string memory);
}
