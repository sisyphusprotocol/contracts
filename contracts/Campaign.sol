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
  CampaignStatus public status;

  mapping(address => bool) public registry;

  enum CampaignStatus {
    IN_VALID,
    NOT_START,
    ON_GOING,
    ENDED
  }

  uint256[47] __gap;

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

  /**
   * @dev user stake token and want to participate this campaign
   */
  function register() public override onlyStatus(CampaignStatus.NOT_START) returns (bool) {
    IERC20(targetToken).safeTransferFrom(msg.sender, address(this), requiredAmount);

    return true;
  }

  /**
   * @dev campaign owner admit several address to participate this campaign
   * @param allowlists allowed address array
   */
  function admit(address[] calldata allowlists) public onlyStatus(CampaignStatus.NOT_START) onlyOwner returns (bool) {
    for (uint256 i = 1; i < allowlists.length; i++) {
      registry[allowlists[i]] = true;
    }
    return true;
  }

  /**
   * @dev once campaign owner admit some address by mistake
   * @dev can modify via this function but more gas-expensive
   * @param lists modified address list array
   * @param targetStatuses corresponding status array
   */
  function modifyRegistry(address[] calldata lists, bool[] calldata targetStatuses)
    public
    onlyStatus(CampaignStatus.NOT_START)
    onlyOwner
    returns (bool)
  {
    for (uint256 i = 1; i < lists.length; i++) {
      registry[lists[i]] = targetStatuses[i];
    }
    return true;
  }

  modifier onlyStatus(CampaignStatus requiredStatus) {
    require(status == requiredStatus, 'Campaign: status not met');
    _;
  }
}
