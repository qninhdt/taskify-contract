// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./TKFToken.sol";

contract TaskElection {
  enum ElectionState {
    OPEN,
    CLOSED,
    CANCALLED
  }

  struct Vote {
    uint256 stake;
    uint candidateId;
  }

  struct Candidate {
    string title;
    uint256 numVotes;
    uint256 totalStakes;
  }

  struct Election {
    uint id;
    string picture;
    string title;
    string description;
    address author;
    ElectionState state;
    uint256 reward; // reward by author
    uint numCandidates;
    uint numVoters;
    uint256 winningCandidateId;
  }

  // election => voter => voted
  mapping(uint => mapping(address => bool)) public voted;

  // election => voter => vote
  mapping(uint => mapping(address => Vote)) public votes;

  // election => candidate[]
  mapping(uint => Candidate[]) public candidates;

  // election => voters[]
  mapping(uint => address[]) public voters;

  uint256 public numElections;
  mapping(uint256 => Election) public elections;

  address public owner;

  TKFToken public tkfToken;

  modifier onlyAuthor(uint256 _electionId) {
    require(
      elections[_electionId].author == msg.sender,
      "Only author can call this function"
    );
    _;
  }

  modifier electionIsOpen(uint256 _electionId) {
    require(
      elections[_electionId].state == ElectionState.OPEN,
      "Election is closed"
    );
    _;
  }

  modifier electionIsClosed(uint256 _electionId) {
    require(
      elections[_electionId].state == ElectionState.CLOSED,
      "Election is not closed"
    );
    _;
  }

  event ElectionCreated(
    uint256 id,
    string picture,
    string title,
    string description,
    address author,
    uint256 reward
  );

  event VoteCasted(
    uint256 electionId,
    address voter,
    uint256 candidateId,
    uint256 stake
  );

  event ElectionFinalized(uint256 electionId, uint256 winningCandidateId);

  event ElectionCancelled(uint256 electionId);

  constructor(address _tkfTokenAddress) {
    owner = msg.sender;
    tkfToken = TKFToken(_tkfTokenAddress);
  }

  function createElection(
    string memory _picture,
    string memory _title,
    string memory _description,
    uint256 _reward,
    string[] memory _candidates
  ) public {
    require(_reward > 0, "Reward must be greater than 0");
    require(_candidates.length > 0, "There must be at least one candidate");

    tkfToken.transferFrom(msg.sender, address(this), _reward);

    uint256 electionId = numElections;
    numElections++;

    elections[electionId] = Election({
      id: electionId,
      picture: _picture,
      title: _title,
      description: _description,
      author: msg.sender,
      state: ElectionState.OPEN,
      reward: _reward,
      numCandidates: _candidates.length,
      numVoters: 0,
      winningCandidateId: 0
    });

    for (uint i = 0; i < _candidates.length; i++) {
      candidates[electionId].push(
        Candidate({title: _candidates[i], numVotes: 0, totalStakes: 0})
      );
    }

    emit ElectionCreated(
      electionId,
      _picture,
      _title,
      _description,
      msg.sender,
      _reward
    );
  }

  function castVote(
    uint256 _electionId,
    uint256 _candidateId,
    uint256 _stake
  ) public electionIsOpen(_electionId) {
    require(msg.sender != elections[_electionId].author, "Author can't vote");
    require(!voted[_electionId][msg.sender], "Already voted");
    require(
      _candidateId < elections[_electionId].numCandidates,
      "Invalid candidate id"
    );
    require(_stake > 0, "Stake must be greater than 0");
    require(tkfToken.balanceOf(msg.sender) >= _stake, "Not enough TKF tokens");

    voted[_electionId][msg.sender] = true;
    voters[_electionId].push(msg.sender);

    elections[_electionId].numVoters++;
    candidates[_electionId][_candidateId].numVotes++;
    candidates[_electionId][_candidateId].totalStakes += _stake;

    tkfToken.transferFrom(msg.sender, address(this), _stake);

    votes[_electionId][msg.sender] = Vote({
      stake: _stake,
      candidateId: _candidateId
    });

    emit VoteCasted(_electionId, msg.sender, _candidateId, _stake);
  }

  function computeResult(
    uint256 _electionId
  ) private electionIsOpen(_electionId) {
    for (uint256 i = 0; i < elections[_electionId].numCandidates; i++) {
      Candidate memory candidate = candidates[_electionId][i];
      if (
        candidate.totalStakes >
        candidates[_electionId][elections[_electionId].winningCandidateId]
          .totalStakes
      ) {
        elections[_electionId].winningCandidateId = i;
      }
    }
  }

  function finalizeElection(
    uint256 _electionId
  ) public onlyAuthor(_electionId) electionIsOpen(_electionId) {
    require(
      elections[_electionId].numVoters > 0,
      "There are no voters in this election"
    );

    uint256 reward = elections[_electionId].reward;
    uint256 numVoters = voters[_electionId].length;
    uint256 numCandidates = candidates[_electionId].length;

    computeResult(_electionId);
    elections[_electionId].state = ElectionState.CLOSED;

    uint256 totalStakes = 0;
    for (uint256 i = 0; i < numCandidates; i++) {
      totalStakes += candidates[_electionId][i].totalStakes;
    }

    uint256 totalReward = reward + totalStakes;
    for (uint256 i = 0; i < numVoters; i++) {
      Vote memory vote = votes[_electionId][voters[_electionId][i]];
      if (vote.candidateId == elections[_electionId].winningCandidateId) {
        tkfToken.transfer(
          voters[_electionId][i],
          (totalReward * vote.stake) /
            candidates[_electionId][vote.candidateId].totalStakes
        );
      }
    }

    emit ElectionFinalized(
      _electionId,
      elections[_electionId].winningCandidateId
    );
  }

  function getMyVote(
    uint256 _electionId
  ) public view electionIsOpen(_electionId) returns (Vote memory) {
    require(voted[_electionId][msg.sender], "You haven't voted");
    return votes[_electionId][msg.sender];
  }

  function cancelElection(
    uint256 _electionId
  ) public onlyAuthor(_electionId) electionIsOpen(_electionId) {
    elections[_electionId].state = ElectionState.CANCALLED;

    tkfToken.transfer(
      elections[_electionId].author,
      elections[_electionId].reward
    );

    for (uint256 i = 0; i < elections[_electionId].numVoters; i++) {
      tkfToken.transfer(
        voters[_electionId][i],
        votes[_electionId][voters[_electionId][i]].stake
      );
    }

    elections[_electionId].numCandidates = 0;
    elections[_electionId].numVoters = 0;

    for (uint256 i = 0; i < elections[_electionId].numCandidates; i++) {
      delete candidates[_electionId][i];
    }

    for (uint256 i = 0; i < elections[_electionId].numVoters; i++) {
      delete votes[_electionId][voters[_electionId][i]];
    }

    emit ElectionCancelled(_electionId);
  }
}
