// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4 ;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract SUN_RISE_NFT_STAKING is Ownable, IERC721Receiver {
    IERC20 reward_token;
    IERC721 nft;

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


    constructor(address _reward_token, address _nft) {
        reward_token = IERC20(_reward_token);
        nft = IERC721(_nft);
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
            uint256 stakedAt = staked.timestamp;
            earned += 1 ether * (block.timestamp - stakedAt) / 1 days;
            delete vault[tokenId];
            emit NFTUnstaked(msg.sender, tokenId, block.timestamp);
            nft.transferFrom(address(this), msg.sender, tokenId);
        }
        earned = earned / 10;
        reward_token.transferFrom(owner(), msg.sender, earned);
        emit Claimed(msg.sender, earned);
    }

    function balanceOf(address account) public view returns (uint256) {
        uint256 balance = 0;
        for(uint i = 1; i <= totalStaked; i++) {
            if (vault[i].owner == account) {
                balance += 1;
            }
        }
        return balance;
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