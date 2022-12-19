// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingPool is Pausable, Ownable {
    // Total amount of ETH staked
    uint256 public totalEthStaked;

    // To check if pool is full or not
    bool public poolFull;

    // To check if rewards are turned on
    bool public rewardsOn;

    // User's staked amount
    mapping(address => uint256) private stakedAmount;

    // --- Events ---
    event Stake(address indexed staker, uint256 stakedAmount);

    event WithdrawStake(address indexed staker, uint256 amountWithdrawn);

    event ClaimRewards(
        address indexed staker,
        uint256 amountClaimed,
        uint256 rewardsClaimed
    );

    // Allow contract to receive ETH
    receive() external payable {}

    constructor() {
        poolFull = false;
        rewardsOn = false;
    }

    // Check if pool is full
    modifier isPoolFull() {
        require(!poolFull, "Pool is full");
        _;
    }

    // --- Admin functions ---
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function turnOnRewards() external onlyOwner {
        rewardsOn = true;
    }

    function turnOffPoolFull() external onlyOwner {
        poolFull = false;
    }

    // Need to complete function with required parameters
    function depositStake() external onlyOwner {
        poolFull = true;

        // Deposit 32 ETH into deposit contract
    }

    // Allow users to stake ETH if pool is not full
    function stakeIntoPool() external payable whenNotPaused isPoolFull {
        // ETH sent from user needs to be greater than 0
        require(msg.value > 0, "Invalid amount");

        // Check if contract ETH balance is over 32 ETH
        require(address(this).balance <= 32.01 ether, "Pool max capacitiy");

        // Update state
        stakedAmount[msg.sender] += msg.value;
        totalEthStaked += msg.value;

        emit Stake(msg.sender, msg.value);
    }

    // Allow users to withdraw their stake if pool is not full
    function withdrawStakeFromPool(
        uint256 amount
    ) external whenNotPaused isPoolFull {
        // Check if user has enough to withdraw
        require(stakedAmount[msg.sender] >= amount, "Insufficient amount");

        // Update state
        stakedAmount[msg.sender] -= amount;
        totalEthStaked -= amount;

        // Send user withdrawal amount
        (bool withdrawal, ) = payable(msg.sender).call{value: amount}("");
        require(withdrawal, "Failed to withdraw");

        emit WithdrawStake(msg.sender, amount);
    }

    // Allow users to unstake a certain amount of ETH + rewards (currently off)
    function unstakeFromPool(uint256 amount) external whenNotPaused {
        require(rewardsOn, "Currently cannot claim rewards");

        uint256 userStakedAmount = stakedAmount[msg.sender];

        // Check if user has enough to claim
        require(userStakedAmount >= amount, "Insufficient amount");

        // Calculate rewards
        uint256 totalStakePortion = (userStakedAmount * 10 ** 18) /
            totalEthStaked;
        uint256 totalContractRewards = address(this).balance - totalEthStaked;
        uint256 totalUserRewards = (totalStakePortion * totalContractRewards) /
            10 ** 18;
        uint256 rewards = (totalUserRewards *
            ((amount * 10 ** 18) / userStakedAmount)) / 10 ** 18;

        // Update state
        stakedAmount[msg.sender] -= amount;
        totalEthStaked -= amount;

        // Send user amount staked + rewards
        (bool claim, ) = payable(msg.sender).call{value: amount + rewards}("");
        require(claim, "Failed to unstake");

        emit ClaimRewards(msg.sender, amount, rewards);
    }

    // Retrieve user's amount of staked ETH
    function stakeOf(address staker) public view returns (uint256) {
        return stakedAmount[staker];
    }

    // Calculate total staker's rewards
    function rewardOf(address staker) public view returns (uint256) {
        uint256 userStakedAmount = stakedAmount[staker];

        if (userStakedAmount == 0) {
            return 0;
        }

        // Calculate rewards
        uint256 totalStakePortion = (userStakedAmount * 10 ** 18) /
            totalEthStaked;
        uint256 totalContractRewards = address(this).balance - totalEthStaked;
        uint256 totalUserRewards = (totalStakePortion * totalContractRewards) /
            10 ** 18;

        return totalUserRewards;
    }
}
