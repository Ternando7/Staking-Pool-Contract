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

    // Allow contract to receive ETH
    receive() external payable {}

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
        uint256 shares = (amount * user.poolShares) / user.stakedEth;

        // Update user stake info
        user.poolShares -= shares;
        user.stakedEth -= amount;

        // Update pool state
        totalEthStaked -= amount;
        totalPoolShares -= shares;

        // Send user withdrawal amount
        (bool withdrawal, ) = payable(msg.sender).call{value: amount}("");
        require(withdrawal, "Failed to withdraw");

        emit WithdrawStake(msg.sender, amount, shares);
    }
}
