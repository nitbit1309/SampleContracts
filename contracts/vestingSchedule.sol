//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";

contract VestingSchedule {
    uint256 public immutable vestingDuration;
    uint256 public immutable cliffPeriod;
    uint256 public immutable startTime;
    address public immutable beneficiary;

    mapping(address => uint256) public erc20TokenReleased;
    uint256 public ethReleased;

    event Erc20TokenTransferred(
        address indexed beneficiary,
        address indexed tokenAddress,
        uint256 value
    );
    event EtherTransferred(address indexed beneficiary, uint256 value);

    // ERC20 token must provide allowance to this address
    constructor(
        address _beneficiary,
        uint256 _duration,
        uint256 _cliff
    ) payable {
        beneficiary = _beneficiary;
        vestingDuration = _duration;
        cliffPeriod = _cliff;
        startTime = block.timestamp;
    }

    receive() external payable {}

    function getReleasableAmount() public view returns (uint256) {
        return _releasableValue(address(this).balance, ethReleased);
    }

    function getReleasableAmount(address _tokenAddress)
        public
        view
        returns (uint256)
    {
        require(_tokenAddress != address(0), "Not a valid token address");
        uint256 bal = IERC20(_tokenAddress).balanceOf(address(this));
        return _releasableValue(bal, erc20TokenReleased[_tokenAddress]);
    }

    function _releasableValue(uint256 _balance, uint256 _releasedAmount)
        internal
        view
        returns (uint256 value)
    {
        uint256 currentTime = block.timestamp;
        if (currentTime < startTime + cliffPeriod) {
            value = 0;
        } else if (currentTime >= startTime + cliffPeriod + vestingDuration) {
            value = _balance;
        } else {
            uint256 totalReleaseable = ((_balance + _releasedAmount) /
                vestingDuration) * (currentTime - ((startTime + cliffPeriod)));
            value = totalReleaseable - _releasedAmount;
        }
    }

    function withdrawReleasedValue(address _tokenAddress, uint256 _value)
        external
    {
        uint256 reasableValue = getReleasableAmount(_tokenAddress);
        require(reasableValue > 0, "No token to be released.");
        require(_value <= reasableValue, "Not enough releasable tokens");

        erc20TokenReleased[_tokenAddress] += _value;

        emit Erc20TokenTransferred(beneficiary, _tokenAddress, _value);
        bool success = IERC20(_tokenAddress).transfer(beneficiary, _value);
        require(success, "Not able to transfer tokens");
    }

    function withdrawReleasedValue(uint256 _value) external {
        require(_value <= address(this).balance, "Not enough ethers");
        ethReleased += _value;
        emit EtherTransferred(beneficiary, _value);
        payable(beneficiary).transfer(_value);
    }
}
