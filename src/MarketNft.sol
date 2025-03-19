// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MarketNft
 * @dev A contract for creating and trading fractional ownership of property NFTs
 */
contract MarketNft is ERC721, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error MarketNFT__PropertyDoesNotExist();
    error MarketNFT__InsufficientPayment();
    error MarketNFT__InsufficientSupply();
    error MarketNFT__InsufficientBalance();
    error MarketNFT__InsufficientFractions();
    error MarketNFT__WithdrawFailed();
    error MarketNFT__Fallback();
    error MarketNFT__PayoutFailed();

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Struct for storing metadata about a property NFT
     * @param name Name of the property
     * @param description Description of the property
     * @param location Physical location of the property
     * @param image URI of the property image
     */
    struct TokenMetadata {
        string name;
        string description;
        string location;
        string image;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private s_tokenCounter;
    uint256 private s_fractionPrice = 0.01 ether;

    mapping(uint256 => string) private s_tokenIdToUri;
    mapping(uint256 => uint256) public s_fractionalSupply;
    mapping(uint256 => mapping(address => uint256)) public s_fractionalBalance;
    mapping(uint256 => TokenMetadata) public s_tokenMetadata;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event FractionPriceUpdated(uint256 newPrice);
    event Withdraw(address indexed owner, uint256 amount);
    event BuyFraction(address indexed buyer, uint256 tokenId, uint256 amount);
    event SellFraction(address indexed seller, uint256 tokenId, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(uint256 price) ERC721("MarketNft", "MNFT") Ownable(msg.sender) {
        s_tokenCounter = 0;
        s_fractionPrice = price;
    }

    modifier exists(uint256 tokenId) {
        if (s_fractionalSupply[tokenId] == 0) {
            revert MarketNFT__PropertyDoesNotExist();
        }
        _;
    }

    /**
     * @notice Mints a new property NFT with fractional ownership
     * @param name Name of the property
     * @param description Description of the property
     * @param location Physical location of the property
     * @param imageUri URI of the property image
     * @param fractions Total number of fractions to create
     */
    function mintNft(
        string memory name,
        string memory description,
        string memory location,
        string memory imageUri,
        uint256 fractions
    ) public onlyOwner {
        uint256 newTokenId = s_tokenCounter;

        // Store metadata directly at mint time
        s_tokenMetadata[newTokenId] = TokenMetadata({
            name: name,
            description: description,
            location: location,
            image: imageUri
        });

        // Store image URI for backward compatibility
        s_tokenIdToUri[newTokenId] = imageUri;

        _safeMint(msg.sender, newTokenId);

        s_fractionalSupply[newTokenId] = fractions;
        s_fractionalBalance[newTokenId][address(this)] = fractions;

        s_tokenCounter++;
    }

    /**
     * @notice Buy fractions of a property NFT
     */
    function buyFraction(uint256 tokenId, uint256 amount) public payable exists(tokenId) {
        if (msg.value < s_fractionPrice * amount) {
            revert MarketNFT__InsufficientPayment();
        }
        if (s_fractionalBalance[tokenId][address(this)] < amount) {
            revert MarketNFT__InsufficientSupply();
        }

        s_fractionalBalance[tokenId][address(this)] -= amount;
        s_fractionalBalance[tokenId][msg.sender] += amount;

        emit BuyFraction(msg.sender, tokenId, amount);
    }

    /**
     * @notice Sell fractions of a property NFT back to the contract
     */
    function sellFraction(uint256 tokenId, uint256 amount) public payable exists(tokenId) {
        if (s_fractionalBalance[tokenId][msg.sender] < amount) {
            revert MarketNFT__InsufficientFractions();
        }
        if (address(this).balance < s_fractionPrice * amount) {
            revert MarketNFT__InsufficientBalance();
        }

        s_fractionalBalance[tokenId][msg.sender] -= amount;
        s_fractionalBalance[tokenId][address(this)] += amount;

        uint256 payment = s_fractionPrice * amount;
        (bool success, ) = payable(msg.sender).call{value: payment}("");
        if (!success) {
            revert MarketNFT__PayoutFailed();
        }

        emit SellFraction(msg.sender, tokenId, amount);
    }

    function setNewFractionPrice(uint256 newPrice) public onlyOwner {
        s_fractionPrice = newPrice;

        emit FractionPriceUpdated(newPrice);
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;

        (bool success, ) = payable(msg.sender).call{value: balance}("");
        if (!success) {
            revert MarketNFT__WithdrawFailed();
        }

        emit Withdraw(msg.sender, balance);
    }

    /**
     * @notice Update metadata for a token
     */
    function setTokenMetadata(
        uint256 tokenId,
        string memory _name,
        string memory _description,
        string memory _location,
        string memory _image
    ) public onlyOwner {
        s_tokenMetadata[tokenId] = TokenMetadata({
            name: _name,
            description: _description,
            location: _location,
            image: _image
        });
    }

    /**
     * @notice Returns the URI for a given token ID
     * @dev Overrides the ERC721 tokenURI function
     */
    function tokenURI(
        uint256 tokenId
    ) public view override exists(tokenId) returns (string memory) {
        TokenMetadata memory metadata = s_tokenMetadata[tokenId];

        // Get the name (custom or contract default)
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name": "',
                                metadata.name,
                                '", "description": "',
                                metadata.description,
                                '", "location": "',
                                metadata.location,
                                '", "image":"',
                                metadata.image,
                                '"}'
                            )
                        )
                    )
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                                 GETTERS
    //////////////////////////////////////////////////////////////*/
    function getPrice() public view returns (uint256) {
        return s_fractionPrice;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getFractionalSupply(uint256 tokenId) public view returns (uint256) {
        return s_fractionalSupply[tokenId];
    }

    function getFractionalBalance(uint256 tokenId, address account) public view returns (uint256) {
        return s_fractionalBalance[tokenId][account];
    }

    function getTokenIdToUri(uint256 tokenId) public view returns (string memory) {
        return s_tokenIdToUri[tokenId];
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function getOwner() public view returns (address) {
        return owner();
    }

    fallback() external payable {
        revert MarketNFT__Fallback();
    }

    receive() external payable {
        revert MarketNFT__Fallback();
    }
}
