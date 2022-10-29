// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4 ;

import "./Shadow_Descendents.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract NFT_STAKING_BNB is Ownable, IERC721Receiver {
    using SafeMath for uint256;
    IERC20 reward_token;
    Shadow_Descendants nft;
    AggregatorV3Interface internal priceFeed;

    uint256 public totalStaked;

    struct Stake {
        uint24 tokenId; 
        uint256 timestamp;
        address owner;
    }

    mapping(uint256 => Stake) public vault;

    event NFTStaked(address owner, uint256 tokenId, uint256 value);
    event NFTUnstaked(address owner, uint256 tokenId, uint256 value);
    event Claimed(address owner, uint256 amount);


    constructor(address _reward_token, Shadow_Descendants _nft) {
        reward_token = IERC20(_reward_token);
        nft = _nft;
        priceFeed = AggregatorV3Interface(0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7);  // goerli test net usdc
    }

    function stake(uint256[] calldata tokenIds) external {
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
                timestamp: block.timestamp
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
                earned += getPeriodReward(staked); // multiply rewards to token decimals
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
                uint256 earned = getPeriodReward(staked); // multiply rewards to token decimals
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
        //return block.timestamp >= (staked.timestamp + (86400 * 30));
        return block.timestamp >= (staked.timestamp + 900);
    }

    function getPeriodReward(Stake memory staked) internal view returns(uint256) {
        uint256 bnbInUsd = uint(getLatestPrice());
        uint256 rewards_30days = 8 * 10**8; // assuming 8 decimals in usd returned by chainlink so its becomes 8 USD
        uint256 rewards_30daysBnb = rewards_30days.mul(10**18).div(bnbInUsd);
        uint256 rewards_per_day_bnb =  rewards_30daysBnb.div(30);
        uint256 diff = block.timestamp.sub(staked.timestamp);
        uint256 noOfDays = diff.div(60*60*24);
        noOfDays = noOfDays > 0 ? noOfDays : 1;
        return rewards_per_day_bnb.mul(noOfDays);

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

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
      require(from == address(0x0), "Cannot send nfts to Vault directly");
      return IERC721Receiver.onERC721Received.selector;
    }

    function getLatestPrice() public view returns (int) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        // return price;
        return 30076609199;
    }

    fallback() external payable {}

    receive() external payable {}


}