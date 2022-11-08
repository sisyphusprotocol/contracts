//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import '@openzeppelin/contracts/utils/Base64.sol';

import './interface/IRenderer.sol';
import './interface/ICampaign.sol';

contract Renderer is IRenderer {
  // caller must be Campaign Contract
  function renderTokenById(uint256 id) public view override returns (string memory) {
    uint256 dayCount = (ICampaign(msg.sender).period() * ICampaign(msg.sender).totalEpochsCount()) / 86400;
    string memory period = string(abi.encode(Strings.toString(dayCount), 'Days'));
    string memory result = ICampaign(msg.sender).getTokenProperties(id).tokenStatus == ICampaign.TokenStatus.FAILED
      ? 'Bravo'
      : 'Failed';
    uint256 process = ((ICampaign(msg.sender).currentEpoch() + 1) * 100) / (ICampaign(msg.sender).totalEpochsCount());
    return renderSvg(address(uint160(id)), IERC721Metadata(msg.sender).name(), result, period, process);
  }

  /**
   * @param addr user addr
   * @param name campaign's name, such as Writing Protocol
   * @param period such as 14 days
   * @param result such as Not Start, Bravo, Failed
   * @param process in percent, 0-100
   */
  function renderSvg(
    address addr,
    string memory name,
    string memory period,
    string memory result,
    uint256 process
  ) internal pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          '<svg width="114" height="175" fill="none" xmlns="http://www.w3.org/2000/svg"><g filter="url(#prefix__filter0_d_774_3790)"><rect x="2" width="110" height="171.459" rx="8.715" fill="url(#prefix__paint0_linear_774_3790)" shape-rendering="crispEdges"/></g><text dx="60" dy="18" dominant-baseline="central" text-anchor="middle" style="height:100px" font-size="7" fill="#000">',
          _shortenAddr(addr),
          '</text><text dx="55" dy="110" dominant-baseline="central" text-anchor="middle" style="height:100px" font-size="7" fill="#000">',
          result,
          '</text><text dx="60" dy="140" dominant-baseline="central" text-anchor="middle" style="height:100px" font-size="6" fill="#000">',
          name,
          '</text><text dx="60" dy="154" dominant-baseline="central" text-anchor="middle" style="height:100px" font-size="7" fill="#000">',
          period,
          '</text><g filter="url(#prefix__filter1_dd_774_3790)" shape-rendering="crispEdges"><circle cx="19.811" cy="17.42" r="10.765" fill="#D9D9D9" fill-opacity=".39"/><circle cx="19.811" cy="17.42" r="10.329" stroke="#000" stroke-opacity=".5" stroke-width=".872"/></g><rect x="17.267" y="117.438" width="82" height="6.655" rx="3.327" fill="#fff"/><rect x="17.267" y="117.438" width="',
          _calculateProgressNumber(process),
          '" height="6.655" rx="3.327" fill="#FD93FF"/><defs><filter id="prefix__filter0_d_774_3790" x=".257" y="0" width="113.486" height="174.945" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feFlood flood-opacity="0" result="BackgroundImageFix"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/><feOffset dy="1.743"/><feGaussianBlur stdDeviation=".872"/><feComposite in2="hardAlpha" operator="out"/><feColorMatrix values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.25 0"/><feBlend in2="BackgroundImageFix" result="effect1_dropShadow_774_3790"/><feBlend in="SourceGraphic" in2="effect1_dropShadow_774_3790" result="shape"/></filter><filter id="prefix__filter1_dd_774_3790" x="7.303" y="6.655" width="25.016" height="25.016" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feFlood flood-opacity="0" result="BackgroundImageFix"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/><feOffset dy="1.743"/><feGaussianBlur stdDeviation=".872"/><feComposite in2="hardAlpha" operator="out"/><feColorMatrix values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.25 0"/><feBlend in2="BackgroundImageFix" result="effect1_dropShadow_774_3790"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/><feOffset dy="1.743"/><feGaussianBlur stdDeviation=".872"/><feComposite in2="hardAlpha" operator="out"/><feColorMatrix values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.25 0"/><feBlend in2="effect1_dropShadow_774_3790" result="effect2_dropShadow_774_3790"/><feBlend in="SourceGraphic" in2="effect2_dropShadow_774_3790" result="shape"/></filter><linearGradient id="prefix__paint0_linear_774_3790" x1="57" y1="0" x2="57" y2="171.459" gradientUnits="userSpaceOnUse"><stop stop-color="#FDFBC2"/><stop offset="1" stop-color="#CF70D5" stop-opacity=".27"/></linearGradient></defs></svg>'
        )
      );
  }

  function _calculateProgressNumber(uint256 process) private pure returns (string memory) {
    return Strings.toString((process * 82) / 100);
  }

  function _substring(
    string memory str,
    uint256 startIndex,
    uint256 endIndex
  ) private pure returns (string memory) {
    bytes memory strBytes = bytes(str);
    bytes memory result = new bytes(endIndex - startIndex);
    for (uint256 i = startIndex; i < endIndex; i++) {
      result[i - startIndex] = strBytes[i];
    }
    return string(result);
  }

  function _shortenAddr(address addr) private pure returns (string memory) {
    uint256 value = uint160(addr);
    bytes memory allBytes = bytes(Strings.toHexString(value, 20));

    string memory newString = string(allBytes);

    return string(abi.encodePacked(_substring(newString, 0, 6), '...', _substring(newString, 38, 42)));
  }
}
