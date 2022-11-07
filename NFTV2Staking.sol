// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4 ;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./ShadowDescendants2.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract V2_STAKING_SUN is Ownable, IERC721Receiver {
    using SafeMath for uint256;
    IERC20 reward_token;
    ShadowDescendants2 nft;

    enum period{SMALL, MEDIUM, LARGE, XLARGE}

    uint256 public totalStaked;
    uint256 public smallOpt = 30;
    uint256 public mediumOpt = 60;
    uint256 public largeOpt = 90;
    uint256 public xlargeOpt = 120;
    uint256 public smallReward = 1000;
    uint256 public mediumReward = 2000;
    uint256 public largeReward = 3000;
    uint256 public xlargeReward = 4000;

    struct Stake {
        uint24 tokenId; 
        uint256 timestamp;
        period stakingPeriod;
        address owner;
    }

    mapping(uint256 => Stake) public vault;

    event NFTStaked(address owner, uint256 tokenId, uint256 value);
    event NFTUnstaked(address owner, uint256 tokenId, uint256 value);
    event Claimed(address owner, uint256 amount);


    constructor(address _reward_token, ShadowDescendants2 _nft) {
        reward_token = IERC20(_reward_token);
        nft = _nft;
    }

    function stake(uint256[] calldata tokenIds, period _stakingPeriod) external {
        uint256 tokenId;
        totalStaked += tokenIds.length;
        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            require(nft.ownerOf(tokenId) == msg.sender, "not your token");
            require(vault[tokenId].tokenId == 0, 'already staked');

            nft.transferFrom(msg.sender, address(this), tokenId);
            emit NFTStaked(msg.sender, tokenId, block.timestamp);

            vault[tokenId] = Stake({
                owner: msg.sender,
                tokenId: uint24(tokenId),
                timestamp: block.timestamp,
                stakingPeriod: _stakingPeriod
            });
        }
    }

    function _unstakeMany(uint256[] calldata tokenIds) external {
        uint256 tokenId;
        totalStaked -= tokenIds.length;
        uint256 earned = 0;
        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            Stake memory staked = vault[tokenId];
            require(staked.owner == msg.sender, "not an owner");
            if(validateStakingPeriod(staked)) {
                earned += getPeriodReward(staked.stakingPeriod) * 10**18; // multiply rewards to token decimals
            }
            delete vault[tokenId];
            emit NFTUnstaked(msg.sender, tokenId, block.timestamp);
            nft.transferFrom(address(this), msg.sender, tokenId);
        }
        if(earned > 0) {
            reward_token.transferFrom(owner(), msg.sender, earned);
            emit Claimed(msg.sender, earned);
        }
    }

    function claimRewards(uint256[] calldata tokenIds) external {
        uint256 tokenId;
        uint256 rewards;
        for (uint i = 0; i < tokenIds.length; i++) {
            tokenId = tokenIds[i];
            Stake memory staked = vault[tokenId];
            require(staked.owner == msg.sender, "not an owner");
            if(validateStakingPeriod(staked)) {
                uint256 earned = getPeriodReward(staked.stakingPeriod) * 10**18; // multiply rewards to token decimals
                if (earned > 0) {
                    staked.timestamp = block.timestamp;
                    vault[tokenId] = staked;
                    rewards += earned;
                }
            }
        }
        if (rewards > 0) {
            reward_token.transferFrom(owner(), msg.sender, rewards);
            emit Claimed(msg.sender, rewards);
        }
        
    }

    function validateStakingPeriod(Stake memory staked) internal view returns(bool) {
        uint256 periodValue = getPeriodValue(staked.stakingPeriod);
        //return block.timestamp >= (staked.timestamp + (86400 * periodValue)); // should be use in mainnet deployment
        return block.timestamp >= (staked.timestamp + 900); // this is for testing.. here its validating only 15 minutes
    }

    function getPeriodValue(period _stPeriod) internal view returns(uint256) {
        return _stPeriod == period.SMALL ? smallOpt : _stPeriod == period.MEDIUM ? mediumOpt : _stPeriod == period.LARGE ? largeOpt : _stPeriod == period.XLARGE ? xlargeOpt : 0;
    }


    function getNFTStakeReward(period _stPeriod, uint256 _stakeTimestamp) internal view returns (uint256) {
        uint256 totalStakeReward = getPeriodReward(_stPeriod);
        uint256 noOfDays = (block.timestamp - _stakeTimestamp).div(60).div(60).div(24);
        noOfDays = (noOfDays < 1) ? 1 : noOfDays;
        uint256 periodValue = getPeriodValue(_stPeriod);
        return totalStakeReward.div(periodValue).mul(noOfDays);
    }

    function getPeriodReward(period _stPeriod) internal view returns(uint256) {
        return _stPeriod == period.SMALL ? smallReward : _stPeriod == period.MEDIUM ? mediumReward : _stPeriod == period.LARGE ? largeReward : _stPeriod == period.XLARGE ? xlargeReward : 0;
    }

    function balanceOf(address account) public view returns (uint256) {
        uint256 balance = 0;
        uint256 supply = nft.totalSupply();
        for(uint i = 1; i <= supply; i++) {
            if (vault[i].owner == account) {
                balance += 1;
            }
        }
        return balance;
    }

    function getUserStakedTokens(address account) public view returns (uint256[] memory) {
        uint256 balance = balanceOf(account);
        uint256[] memory tokenIds = new uint[](balance);
        uint256 supply = nft.totalSupply();
        uint256 index = 0;
        for(uint i = 1; i <= supply; i++) {
            if (vault[i].owner == account) {
                tokenIds[index] = vault[i].tokenId;
                index++;
            }
        }
        return tokenIds;
    }


    function setSmallOpt(uint256 _periodOpt) public onlyOwner {
        smallOpt = _periodOpt;
    }

    function setMediumOpt(uint256 _periodOpt) public onlyOwner {
        mediumOpt = _periodOpt;
    }

    function setLargeOpt(uint256 _periodOpt) public onlyOwner {
        largeOpt = _periodOpt;
    }

    function setXlargeOpt(uint256 _periodOpt) public onlyOwner {
        xlargeOpt = _periodOpt;
    }

    
    function setsmallReward(uint256 _reward) public onlyOwner {
        smallReward = _reward;
    }

    function setmediumReward(uint256 _reward) public onlyOwner {
        mediumReward = _reward;
    }

    function setlargeReward(uint256 _reward) public onlyOwner {
        largeReward = _reward;
    }

    function setxlargeReward(uint256 _reward) public onlyOwner {
        xlargeReward = _reward;
    }

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
      require(from == address(0x0), "Cannot send nfts to Vault directly");
      return IERC721Receiver.onERC721Received.selector;
    }

}