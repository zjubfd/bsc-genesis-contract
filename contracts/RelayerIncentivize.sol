pragma solidity 0.6.4;

import "./interface/IRelayerIncentivize.sol";
import "./System.sol";
import "./lib/SafeMath.sol";

contract RelayerIncentivize is IRelayerIncentivize, System {

  using SafeMath for uint256;

  uint256 public constant ROUND_SIZE=1000;
  uint256 public constant MAXIMUM_WEIGHT=400;

  //TODO add governance later
  uint256 public constant moleculeHeaderRelayer = 1;
  uint256 public constant denominatorHeaderRelayer = 5;
  uint256 public constant moleculeCallerCompensation = 1;
  uint256 public constant denominatorCallerCompensation = 80;

  mapping(address => uint256) public headerRelayersSubmitCount;
  address payable[] public headerRelayerAddressRecord;

  mapping(address => uint256) public transferRelayersSubmitCount;
  address payable[] public transferRelayerAddressRecord;

  uint256 public collectedRewardForHeaderRelayer=0;
  uint256 public collectedRewardForTransferRelayer=0;

  uint256 public roundSequence=0;
  uint256 public countInRound=0;

  event LogDistributeCollectedReward(uint256 sequence, uint256 roundRewardForHeaderRelayer, uint256 roundRewardForTransferRelayer);

  
  function addReward(address payable headerRelayerAddr, address payable caller) external onlyTokenHub override payable returns (bool) {
  
    countInRound++;

    uint256 reward = calculateRewardForHeaderRelayer(msg.value);
    collectedRewardForHeaderRelayer = collectedRewardForHeaderRelayer.add(reward);
    collectedRewardForTransferRelayer = collectedRewardForTransferRelayer.add(msg.value).sub(reward);

    if (headerRelayersSubmitCount[headerRelayerAddr]==0){
      headerRelayerAddressRecord.push(headerRelayerAddr);
    }
    headerRelayersSubmitCount[headerRelayerAddr]++;

    if (transferRelayersSubmitCount[caller]==0){
      transferRelayerAddressRecord.push(caller);
    }
    transferRelayersSubmitCount[caller]++;

    if (countInRound==ROUND_SIZE){
      emit LogDistributeCollectedReward(roundSequence, collectedRewardForHeaderRelayer, collectedRewardForTransferRelayer);

      distributeHeaderRelayerReward(caller);
      distributeTransferRelayerReward(caller);

      address payable systemPayable = address(uint160(SYSTEM_REWARD_ADDR));
      systemPayable.transfer(address(this).balance);

      roundSequence++;
      countInRound = 0;
    }
    return true;
  }

  function calculateRewardForHeaderRelayer(uint256 reward) internal view returns (uint256) {
    return reward.mul(moleculeHeaderRelayer).div(denominatorHeaderRelayer);
  }

  function distributeHeaderRelayerReward(address payable caller) internal returns (bool) {
    uint256 totalReward = collectedRewardForHeaderRelayer;

    uint256 totalWeight=0;
    address payable[] memory relayers = headerRelayerAddressRecord;
    uint256[] memory relayerWeight = new uint256[](relayers.length);
    for(uint256 index = 0; index < relayers.length; index++) {
      address relayer = relayers[index];
      uint256 weight = calculateHeaderRelayerWeight(headerRelayersSubmitCount[relayer]);
      relayerWeight[index] = weight;
      totalWeight = totalWeight.add(weight);
    }

    uint256 callerReward = totalReward.mul(moleculeCallerCompensation).div(denominatorCallerCompensation);
    totalReward = totalReward.sub(callerReward);
    uint256 remainReward = totalReward;
    for(uint256 index = 1; index < relayers.length; index++) {
      uint256 reward = relayerWeight[index].mul(totalReward).div(totalWeight);
      relayers[index].send(reward);
      remainReward = remainReward.sub(reward);
    }
    relayers[0].send(remainReward);
    caller.send(callerReward);

    collectedRewardForHeaderRelayer = 0;
    for (uint256 index = 0; index < relayers.length; index++){
      delete headerRelayersSubmitCount[relayers[index]];
    }
    delete headerRelayerAddressRecord;
  }

  function distributeTransferRelayerReward(address payable caller) internal returns (bool) {
    uint256 totalReward = collectedRewardForTransferRelayer;

    uint256 totalWeight=0;
    address payable[] memory relayers = transferRelayerAddressRecord;
    uint256[] memory relayerWeight = new uint256[](relayers.length);
    for(uint256 index = 0; index < relayers.length; index++) {
      address relayer = relayers[index];
      uint256 weight = calculateTransferRelayerWeight(transferRelayersSubmitCount[relayer]);
      relayerWeight[index] = weight;
      totalWeight = totalWeight + weight;
    }

    uint256 callerReward = totalReward.mul(moleculeCallerCompensation).div(denominatorCallerCompensation);
    totalReward = totalReward.sub(callerReward);
    uint256 remainReward = totalReward;
    for(uint256 index = 1; index < relayers.length; index++) {
      uint256 reward = relayerWeight[index].mul(totalReward).div(totalWeight);
      relayers[index].send(reward);
      remainReward = remainReward.sub(reward);
    }
    relayers[0].send(remainReward);
    caller.send(callerReward);

    collectedRewardForTransferRelayer = 0;
    for (uint256 index = 0; index < relayers.length; index++){
      delete transferRelayersSubmitCount[relayers[index]];
    }
    delete transferRelayerAddressRecord;
  }

  function calculateTransferRelayerWeight(uint256 count) public pure returns(uint256) {
    if (count <= MAXIMUM_WEIGHT) {
      return count;
    } else if (MAXIMUM_WEIGHT < count && count <= 2*MAXIMUM_WEIGHT) {
      return MAXIMUM_WEIGHT;
    } else if (2*MAXIMUM_WEIGHT < count && count <= (2*MAXIMUM_WEIGHT + 3*MAXIMUM_WEIGHT/4 )) {
      return 3*MAXIMUM_WEIGHT - count;
    } else {
      return count/4;
    }
  }

  function calculateHeaderRelayerWeight(uint256 count) public pure returns(uint256) {
    if (count <= MAXIMUM_WEIGHT) {
      return count;
    } else {
      return MAXIMUM_WEIGHT;
    }
  }
}
