// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";

contract Voting {
    uint256 public immutable MINIMUM_WEI_PER_VOTING = 0.01 ether;
    uint256 public immutable WEI_PER_STAKE = 0.001 ether;

    struct Voter {
        address payable addr;
        uint256 stake;
        uint value;
    }

    address payable public owner;
    uint public numCandidate;
    uint256 public reward;

    bool public finished = false;

    mapping(address => Voter) private voters;
    mapping(uint => uint256) private stakeCount;
    uint private winningCandidate;
    address[] private votersAddresses;

    constructor(uint _numCandidate) payable {
        require(msg.value >= MINIMUM_WEI_PER_VOTING, "Not enough reward");
        require(_numCandidate >= 2, "At least 2 candidates");

        reward = msg.value;
        numCandidate = _numCandidate;

        owner = payable(msg.sender);

        console.log(MINIMUM_WEI_PER_VOTING);
        console.log(WEI_PER_STAKE);
    }

    function vote(uint value, uint256 stake) public payable {
        require(!finished, "Voting is finished");
        require(voters[msg.sender].addr == address(0), "You already voted");
        require(value < numCandidate, "Invalid value");
        require(stake >= 1, "You need to stake at least 1");
        require(stake * WEI_PER_STAKE >= msg.value, "Not enough wei");
        require(owner != msg.sender, "Owner cannot vote");

        Voter memory voter = Voter(payable(msg.sender), stake, value);
        voters[msg.sender] = voter;
        votersAddresses.push(msg.sender);
        stakeCount[value] += stake;

        reward += stake * WEI_PER_STAKE;
    }

    function close() public {
        require(msg.sender == owner, "Only owner can close voting");

        finished = true;

        uint256 winningStake = 0;
        for (uint i = 0; i < numCandidate; i++) {
            if (stakeCount[i] > winningStake) {
                winningCandidate = i;
                winningStake = stakeCount[i];
            }
        }

        uint256 rewardPerStake = reward / winningStake;
        for (uint256 i = 0; i < votersAddresses.length; i++) {
            Voter memory voter = voters[votersAddresses[i]];

            if (voter.value == winningCandidate) {
                voter.addr.transfer(rewardPerStake * voter.stake);
            }
        }
    }

    function getWinningCandidate() public view returns (uint) {
        require(finished, "Voting is not finished");

        return winningCandidate;
    }
}
