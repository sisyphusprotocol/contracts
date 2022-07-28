//SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.15;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './interface/ICampaign.sol';

contract Campaign is ICampaign, Ownable, ERC721 {
  using SafeERC20 for IERC20;

  IERC20 public immutable targetToken;
  uint256 public immutable requiredAmount;

  mapping(address => bool) public registry;

  constructor(
    IERC20 token_,
    uint256 amount_,
    string memory name_,
    string memory symbol_
  ) ERC721(name_, symbol_) {
    require(address(token_) != address(0), 'Campaign: invalid token');
    require(amount_ != 0, 'Campaign: invalid amount');
    targetToken = token_;
    requiredAmount = amount_;
  }

  function register() public override returns (bool) {
    IERC20(targetToken).safeTransferFrom(msg.sender, address(this), requiredAmount);

    registry[msg.sender] = true;

    return true;
  }
}
