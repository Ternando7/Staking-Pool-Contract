// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingPool is Pausable, Ownable {
    // Total amount of ETH staked
    uint256 totalEthStaked;

    // Total amount of pool shares
    uint256 totalPoolShares;

    // To check if pool is full or not
    bool poolFull;

    // To check if rewards are turned on
    bool rewardsOn;

    // Stake info
    struct StakeInfo {
        uint256 stakedEth;
        uint256 poolShares;
    }

    // Each user's stake info
    mapping(address => StakeInfo) public userStakeInfo;

    // --- Events ---
    event Stake(
        address indexed staker,
        uint256 stakedAmount,
        uint256 poolShares
    );

    event WithdrawStake(
        address indexed staker,
        uint256 amountWithdrawn,
        uint256 sharesWithdrawn
    );

    event ClaimRewards(
        address indexed staker,
        uint256 amountClaimed,
        uint256 sharesClaimed,
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

    // Need to complete function with required parameters
    function depositStake() external onlyOwner {
        poolFull = true;

        // Deposit 32 ETH into deposit contract
    }

    // Allow users to stake ETH if pool is not full
    function stake() external payable whenNotPaused isPoolFull {
        // ETH sent from user needs to be greater than 0
        require(msg.value > 0, "Invalid amount");

        // Check if pool is empty
        if (totalEthStaked == 0 && totalPoolShares == 0) {
            // User gets 1:1 ratio of pool shares to ETH staked
            userStakeInfo[msg.sender] = StakeInfo({
                stakedEth: msg.value,
                poolShares: msg.value
            });

            // Update state
            totalEthStaked += msg.value;
            totalPoolShares += msg.value;

            emit Stake(msg.sender, msg.value, msg.value);
        } else {
            // Calculate user pool shares (includes rewards once they are available)
            uint256 userShares = (msg.value * totalPoolShares) /
                address(this).balance;

            // Update user stake info
            userStakeInfo[msg.sender].stakedEth += msg.value;
            userStakeInfo[msg.sender].poolShares += userShares;

            // Update pool state
            totalEthStaked += msg.value;
            totalPoolShares += userShares;

            emit Stake(msg.sender, msg.value, userShares);
        }
    }

    // Allow users to withdraw their stake if pool is not full
    function withdrawStake(uint256 amount) external whenNotPaused isPoolFull {
        // Get user stake info from storage
        StakeInfo storage user = userStakeInfo[msg.sender];

        // Check if user has enough to withdraw
        require(user.stakedEth >= amount, "Insufficient amount");

        // Calculate user pool shares to withdraw
        uint256 sharesToWithdraw = (amount * user.poolShares) / user.stakedEth;

        // Update user stake info
        user.poolShares -= sharesToWithdraw;
        user.stakedEth -= amount;

        // Update pool state
        totalEthStaked -= amount;
        totalPoolShares -= sharesToWithdraw;

        // Send user withdrawal amount
        (bool withdrawal, ) = payable(msg.sender).call{value: amount}("");
        require(withdrawal, "Failed to withdraw");

        emit WithdrawStake(msg.sender, amount, sharesToWithdraw);
    }

    // Allow users to unstake a certain amount of ETH + rewards (currently off)
    function unstake(uint256 amount) external whenNotPaused {
        require(rewardsOn, "Currently cannot claim rewards");

        // Get user stake info from storage
        StakeInfo storage user = userStakeInfo[msg.sender];

        // Check if user has enough to claim
        require(user.stakedEth >= amount, "Insufficient amount");

        // Calculate user pool shares to claim
        uint256 sharesToClaim = (amount * user.poolShares) / user.stakedEth;

        /**
         * Calculate Rewards:
         *
         * Rewards =
         *
         * [(Shares to claim) * (total ETH / total shares)] - [(Shares to claim) * (user staked ETH / user pool shares)]
         *
         * @notice Explanation: User shares to claim is multiplied by the total ETH/share ratio to get
         * how much ETH per share this user should receive. Notice total ETH/share ratio is going to start
         * from 1 and then continuosly increase as rewards are added to this contract. Then, calculate
         * how much ETH is staked by the user shares by multiplying user shares to claim by the user
         * stakedETH/poolShares ratio. After, subtract how much ETH is staked by the user shares from the
         * total amount of ETH for the user to receive to get how much rewards the user should receive.
         */
        uint256 totalReceiveAmount = (sharesToClaim) *
            ((address(this).balance * (10 ** 18)) / totalPoolShares);
        uint256 totalStakedAmount = (sharesToClaim) *
            ((user.stakedEth * (10 ** 18)) / user.poolShares);

        uint256 rewards = (totalReceiveAmount - totalStakedAmount) / 10 ** 18;

        // Update user stake info
        user.poolShares -= sharesToClaim;
        user.stakedEth -= amount;

        // Update pool state
        totalEthStaked -= amount;
        totalPoolShares -= sharesToClaim;

        // Send user amount staked + rewards
        (bool claim, ) = payable(msg.sender).call{value: amount + rewards}("");
        require(claim, "Failed to unstake");

        emit ClaimRewards(msg.sender, amount, sharesToClaim, rewards);
    }
}
