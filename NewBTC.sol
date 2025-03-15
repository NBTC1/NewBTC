// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title NewBTC (NBTC) - Fair Distribution Token
 * @dev A decentralized token with daily random distribution on BNB Chain.
 *      Users send 0.1 BNB to participate, one winner takes daily NBTC reward,
 *      remaining BNB and unclaimed rewards go to a fixed address.
 */
contract NewBTC {
    // Token metadata
    string public constant name = "NewBTC";
    string public constant symbol = "NBTC";
    uint8 public constant decimals = 18;
    uint256 public constant TOTAL_SUPPLY = 21_000_000 * 10**18; // 21 million NBTC
    uint256 public constant COMMUNITY_RESERVE = 1_560 * 10**18; // 1,560 NBTC
    uint256 public constant PARTICIPATION_FEE = 0.1 ether; // 0.1 BNB

    // Distribution state
    uint256 public dailyReward = 6_480 * 10**18; // Initial reward: 6,480 NBTC
    uint256 public dayCount = 0; // Current day index
    uint256 public dayStartTime; // Start of current day (UTC 00:00 approximation)

    // Addresses
    address public immutable owner; // Deployer
    address public constant FUND_ADDRESS = 0xF113275FECc41f396603B677df15eCd1B4A966DB; // BNB and reserve recipient

    // Balances and participants
    mapping(address => uint256) public balances; // NBTC balances
    address[] public participants; // Daily participants

    // Events
    event Participated(address indexed participant, uint256 day);
    event WinnerSelected(address indexed winner, uint256 reward, uint256 day);
    event FundsTransferred(address indexed to, uint256 amount);
    event UnclaimedRewardTransferred(address indexed to, uint256 reward, uint256 day);

    /**
     * @dev Constructor mints total supply, sends community reserve, and sets initial time.
     */
    constructor() {
        owner = msg.sender;
        balances[address(this)] = TOTAL_SUPPLY; // Mint all NBTC to contract
        balances[address(this)] -= COMMUNITY_RESERVE;
        balances[FUND_ADDRESS] += COMMUNITY_RESERVE; // Send 1,560 NBTC to FUND_ADDRESS
        dayStartTime = (block.timestamp / 1 days) * 1 days; // Align to UTC 00:00
    }

    /**
     * @notice Users participate by sending 0.1 BNB during the daily window.
     */
    function participate() external payable {
        require(msg.value == PARTICIPATION_FEE, "Must send exactly 0.1 BNB");
        require(block.timestamp < dayStartTime + 1 days, "Day ended");
        participants.push(msg.sender);
        emit Participated(msg.sender, dayCount);
    }

    /**
     * @notice Automatically selects a random winner or transfers reward if no participants.
     * @dev Anyone can call, triggers once per day after time passes.
     */
    function selectWinner() external {
        require(block.timestamp >= dayStartTime + 1 days, "Day not ended");
        require(dailyReward > 0, "No rewards left");

        if (participants.length > 0) {
            // Randomly select winner if there are participants
            uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, dayCount))) % participants.length;
            address winner = participants[randomIndex];

            // Transfer NBTC reward to winner
            balances[address(this)] -= dailyReward;
            balances[winner] += dailyReward;
            emit WinnerSelected(winner, dailyReward, dayCount);
        } else {
            // Transfer NBTC to FUND_ADDRESS if no participants
            balances[address(this)] -= dailyReward;
            balances[FUND_ADDRESS] += dailyReward;
            emit UnclaimedRewardTransferred(FUND_ADDRESS, dailyReward, dayCount);
        }

        // Transfer all BNB to FUND_ADDRESS
        uint256 bnbAmount = address(this).balance;
        if (bnbAmount > 0) {
            payable(FUND_ADDRESS).transfer(bnbAmount);
            emit FundsTransferred(FUND_ADDRESS, bnbAmount);
        }

        // Update state
        dayCount++;
        dailyReward -= 1 * 10**18; // Decrease reward by 1 NBTC
        dayStartTime += 1 days; // Move to next day
        delete participants; // Reset participants
    }

    /**
     * @notice Returns NBTC balance of an address.
     * @param account Address to query.
     * @return Balance in NBTC.
     */
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    /**
     * @notice Returns current participant count.
     * @return Number of participants.
     */
    function getParticipantCount() external view returns (uint256) {
        return participants.length;
    }
}