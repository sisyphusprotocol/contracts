//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.15;

import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol';
import '@openzeppelin/contracts/utils/Base64.sol';

import './interface/IRenderer.sol';
import './interface/ICampaign.sol';

contract Renderer is IRenderer {
  string constant NOT_START_ICON =
    '<rect x="42.005" y="63.51" width="31.204" height="6.832" rx="3.416" stroke="#8067C7" stroke-width="2"/><circle cx="57.608" cy="66.485" r="22.051" stroke="#8067C7" stroke-width="2"/><path d="M94.595 82.178c-.5 1.312-1.907 2.315-4.254 2.913-2.33.593-5.47.753-9.217.472-7.487-.56-17.278-2.865-27.589-6.794-10.31-3.93-19.153-8.725-25.113-13.29-2.983-2.284-5.221-4.492-6.566-6.486-1.353-2.008-1.736-3.694-1.236-5.006.5-1.312 1.908-2.316 4.254-2.913 2.33-.593 5.47-.753 9.217-.472 7.487.56 17.278 2.865 27.59 6.794 10.31 3.93 19.152 8.725 25.113 13.29 2.983 2.283 5.22 4.492 6.565 6.486 1.354 2.008 1.736 3.694 1.236 5.006z" stroke="#FD93FF"/>';

  string constant ON_GOING_ICON =
    '<path d="M94.595 84.617c-.5 1.311-1.907 2.315-4.254 2.913-2.33.593-5.47.753-9.217.472-7.487-.56-17.278-2.865-27.589-6.794-10.31-3.93-19.153-8.725-25.113-13.29-2.983-2.284-5.221-4.492-6.566-6.486-1.353-2.008-1.736-3.694-1.236-5.006.5-1.312 1.908-2.316 4.254-2.913 2.33-.593 5.47-.753 9.217-.472 7.487.56 17.278 2.865 27.59 6.794 10.31 3.93 19.152 8.725 25.113 13.29 2.983 2.284 5.22 4.492 6.565 6.486 1.354 2.007 1.736 3.694 1.236 5.005z" stroke="#FD93FF"/><path d="M81.256 67.994c1.334.77 1.334 2.694 0 3.464L63.007 81.994c-1.333.77-3-.192-3-1.732V59.19c0-1.54 1.667-2.502 3-1.732l18.25 10.536zM56.018 67.994c1.333.77 1.333 2.694 0 3.464l-18.25 10.536c-1.333.77-3-.192-3-1.732V59.19c0-1.54 1.667-2.502 3-1.732l18.25 10.536z" stroke="#8067C7" stroke-width="2"/>';
  string constant FAILED_ICON =
    '<path d="M94.595 79.758c-.5 1.312-1.908 2.316-4.254 2.913-2.33.594-5.47.753-9.217.473-7.487-.56-17.278-2.865-27.59-6.794-10.31-3.93-19.152-8.725-25.113-13.29-2.983-2.284-5.22-4.493-6.565-6.486-1.354-2.008-1.736-3.694-1.236-5.006.5-1.312 1.907-2.316 4.254-2.913 2.33-.594 5.47-.753 9.217-.473 7.487.56 17.278 2.865 27.589 6.794 10.31 3.93 19.153 8.725 25.113 13.29 2.983 2.284 5.221 4.493 6.566 6.486 1.353 2.008 1.736 3.694 1.236 5.006z" stroke="#FD93FF"/><path d="M50.844 46.246l3.072 28.664a3 3 0 002.983 2.68h1.132a3 3 0 002.98-2.654l3.327-28.664a3 3 0 00-2.98-3.346h-7.531a3 3 0 00-2.983 3.32z" stroke="#8067C7" stroke-width="2" stroke-linejoin="round"/><circle cx="57.607" cy="86.519" r="5.485" stroke="#8067C7" stroke-width="2"/>';
  string constant BRAVO_ICON =
    '<path d="M96.018 82.06c-.634 1.376-2.22 2.347-4.766 2.815-2.53.465-5.89.408-9.862-.16-7.938-1.138-18.204-4.3-28.905-9.229-10.7-4.928-19.776-10.675-25.799-15.97-3.014-2.648-5.241-5.165-6.532-7.39-1.3-2.239-1.591-4.075-.957-5.451.633-1.377 2.219-2.348 4.765-2.816 2.53-.465 5.89-.408 9.862.16 7.938 1.137 18.204 4.3 28.905 9.229 10.7 4.928 19.776 10.675 25.8 15.969 3.013 2.65 5.24 5.166 6.531 7.39 1.3 2.24 1.592 4.076.958 5.452z" stroke="#FD93FF"/><path d="M32.083 61.53l4.008 17.815a2 2 0 001.951 1.56h39.776a2 2 0 001.962-1.615l3.502-17.905c.314-1.609-1.334-2.892-2.817-2.192l-9.025 4.26a2 2 0 01-2.578-.794l-9.131-15.524a2 2 0 00-3.404-.073L46.174 62.755a2 2 0 01-2.543.717l-8.732-4.184c-1.507-.722-3.182.613-2.815 2.243z" stroke="#8067C7" stroke-width="2"/><circle cx="58.071" cy="42.77" r="2.7" stroke="#8067C7" stroke-width="2"/><circle cx="83.279" cy="56.272" r="2.7" stroke="#8067C7" stroke-width="2"/><circle cx="32.144" cy="56.272" r="2.7" stroke="#8067C7" stroke-width="2"/>';

  // caller must be Campaign Contract
  function renderTokenById(uint256 id) public view override returns (string memory) {
    uint256 dayCount = (ICampaign(msg.sender).period() * ICampaign(msg.sender).totalEpochsCount()) / 86400;
    string memory period = string(abi.encodePacked(Strings.toString(dayCount), ' Days'));
    (string memory result, uint256 process, string memory icon) = _getResult(id);

    return renderSvg(IERC721(msg.sender).ownerOf(id), IERC721Metadata(msg.sender).name(), period, result, icon, process);
  }

  function _getResult(uint256 id)
    private
    view
    returns (
      string memory result,
      uint256 progress,
      string memory icon
    )
  {
    if (block.timestamp < ICampaign(msg.sender).startTime()) {
      result = 'Not Started';
      progress = 0;
      icon = NOT_START_ICON;
    } else if (
      block.timestamp <
      ICampaign(msg.sender).startTime() + ICampaign(msg.sender).period() * (ICampaign(msg.sender).totalEpochsCount())
    ) {
      result = 'OnGoing';
      progress = ((ICampaign(msg.sender).currentEpoch() + 1) * 100) / (ICampaign(msg.sender).totalEpochsCount());
      icon = ON_GOING_ICON;
    } else if (ICampaign(msg.sender).getTokenProperties(id).tokenStatus == ICampaign.TokenStatus.FAILED) {
      result = 'Failed';
      progress = ((ICampaign(msg.sender).currentEpoch() + 1) * 100) / (ICampaign(msg.sender).totalEpochsCount());
      icon = FAILED_ICON;
    } else if (ICampaign(msg.sender).getTokenProperties(id).tokenStatus == ICampaign.TokenStatus.ACHIEVED) {
      result = 'Bravo';
      progress = 100;
      icon = BRAVO_ICON;
    }
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
    string memory icon,
    uint256 process
  ) internal pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          '<svg width="115" height="176" fill="none" xmlns="http://www.w3.org/2000/svg"><g filter="url(#prefix__filter0_d_855_3943)"><path d="M2.607 9.64A9.308 9.308 0 0111.915.334H103.3a9.307 9.307 0 019.307 9.308v152.844a9.307 9.307 0 01-9.307 9.307H11.915a9.307 9.307 0 01-9.308-9.307V9.641z" fill="url(#prefix__paint0_linear_855_3943)"/></g><text dx="40" dy="146" dominant-baseline="central" text-anchor="middle" style="height:100px" font-size="8" fill="#000">',
          string(name),
          '</text><text dx="37" dy="15" dominant-baseline="central" text-anchor="middle" style="height:100px" font-size="7" fill="#000">',
          string(_shortenAddr(addr)),
          '</text><text dx="57" dy="112" dominant-baseline="central" text-anchor="middle" style="height:100px" font-size="9" fill="#000">',
          string(result),
          '</text><text dx="29" dy="158" dominant-baseline="central" text-anchor="middle" style="height:100px" font-size="8" fill="#000">',
          string(period),
          '</text><text dx="58" dy="134" dominant-baseline="central" text-anchor="middle" style="height:100px" font-size="6" fill="#000">',
          _calculateProgressPercent(process),
          '</text><rect x="12.607" y="120.544" width="90" height="6.655" rx="3.327" fill="#fff"/><rect x="12.607" y="120.59" width="',
          string(_calculateProgressNumber(process)),
          '" height="6.609" rx="3.304" fill="#FD93FF"/>',
          icon,
          '<path d="M96.466 150.927l-.05.049-.053-.049c-2.324-2.109-3.86-3.504-3.86-4.918 0-.978.733-1.712 1.712-1.712.753 0 1.487.489 1.747 1.154h.91c.26-.665.993-1.154 1.747-1.154.978 0 1.712.734 1.712 1.712 0 1.414-1.536 2.809-3.865 4.918zm2.153-7.609a2.94 2.94 0 00-2.202 1.018 2.941 2.941 0 00-2.202-1.018 2.662 2.662 0 00-2.692 2.691c0 1.845 1.664 3.357 4.184 5.642l.71.646.71-.646c2.52-2.285 4.183-3.797 4.183-5.642a2.662 2.662 0 00-2.691-2.691z" fill="#000"/><defs><linearGradient id="prefix__paint0_linear_855_3943" x1="59.096" y1=".333" x2="59.096" y2="171.792" gradientUnits="userSpaceOnUse"><stop stop-color="#D7ECFF"/><stop offset="1" stop-color="#FCD3FF"/></linearGradient><filter id="prefix__filter0_d_855_3943" x=".746" y=".333" width="113.723" height="175.182" filterUnits="userSpaceOnUse" color-interpolation-filters="sRGB"><feFlood flood-opacity="0" result="BackgroundImageFix"/><feColorMatrix in="SourceAlpha" values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 127 0" result="hardAlpha"/><feOffset dy="1.862"/><feGaussianBlur stdDeviation=".931"/><feComposite in2="hardAlpha" operator="out"/><feColorMatrix values="0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0.25 0"/><feBlend in2="BackgroundImageFix" result="effect1_dropShadow_855_3943"/><feBlend in="SourceGraphic" in2="effect1_dropShadow_855_3943" result="shape"/></filter></defs></svg>'
        )
      );
  }

  function _calculateProgressPercent(uint256 process) private pure returns (string memory) {
    return string(abi.encodePacked(Strings.toString(process), '%'));
  }

  function _calculateProgressNumber(uint256 process) private pure returns (string memory) {
    return Strings.toString((process * 90) / 100);
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
