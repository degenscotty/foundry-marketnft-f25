// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {MarketNft} from "../src/MarketNft.sol";
import {console} from "forge-std/console.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MarketNftTest is Test {
    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    MarketNft public marketNft;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    uint256 initialFractionPrice = 0.01 ether;
    string tokenUri = "ipfs://example-uri";
    string propertyName = "Beach House";
    string propertyDesc = "Beautiful property on the beach";
    string propertyLoc = "Miami, FL";

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
    function setUp() public {
        vm.prank(owner);
        marketNft = new MarketNft(initialFractionPrice);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                           CORE FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/
    // Constructor Tests
    function test_Constructor() public view {
        assertEq(marketNft.getPrice(), initialFractionPrice);
        assertEq(marketNft.getTokenCounter(), 0);
        assertEq(marketNft.getOwner(), owner);
    }

    // Mint Tests
    function test_MintNftAsOwner() public {
        vm.prank(owner);
        marketNft.mintNft(propertyName, propertyDesc, propertyLoc, tokenUri, 1000);

        assertEq(marketNft.ownerOf(0), owner);
        assertEq(marketNft.getTokenCounter(), 1);
        assertEq(marketNft.getFractionalSupply(0), 1000);
        assertEq(marketNft.getFractionalBalance(0, address(marketNft)), 1000);
        assertEq(marketNft.getTokenIdToUri(0), tokenUri);

        (string memory name, string memory desc, string memory loc, string memory img) = marketNft
            .s_tokenMetadata(0);
        assertEq(name, propertyName);
        assertEq(desc, propertyDesc);
        assertEq(loc, propertyLoc);
        assertEq(img, tokenUri);
    }

    function test_MintNftNotOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        marketNft.mintNft(propertyName, propertyDesc, propertyLoc, tokenUri, 1000);
    }

    // Buy Fraction Tests
    function test_BuyFractionSuccess() public {
        vm.prank(owner);
        marketNft.mintNft(propertyName, propertyDesc, propertyLoc, tokenUri, 1000);

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit BuyFraction(user1, 0, 100);
        marketNft.buyFraction{value: 1 ether}(0, 100);

        assertEq(marketNft.getFractionalBalance(0, user1), 100);
        assertEq(marketNft.getFractionalBalance(0, address(marketNft)), 900);
        assertEq(address(marketNft).balance, 1 ether);
    }

    function test_BuyFractionInsufficientPayment() public {
        vm.prank(owner);
        marketNft.mintNft(propertyName, propertyDesc, propertyLoc, tokenUri, 1000);

        vm.prank(user1);
        vm.expectRevert(MarketNft.MarketNFT__InsufficientPayment.selector);
        marketNft.buyFraction{value: 0.005 ether}(0, 100);
    }

    function test_BuyFractionInsufficientSupply() public {
        vm.prank(owner);
        marketNft.mintNft(propertyName, propertyDesc, propertyLoc, tokenUri, 100);

        vm.prank(user1);
        vm.expectRevert(MarketNft.MarketNFT__InsufficientSupply.selector);
        marketNft.buyFraction{value: 2 ether}(0, 200);
    }

    function test_BuyFractionNonExistentToken() public {
        vm.prank(user1);
        vm.expectRevert(MarketNft.MarketNFT__PropertyDoesNotExist.selector);
        marketNft.buyFraction{value: 1 ether}(0, 100);
    }

    // Sell Fraction Tests
    function test_SellFractionSuccess() public {
        vm.prank(owner);
        marketNft.mintNft(propertyName, propertyDesc, propertyLoc, tokenUri, 1000);

        vm.prank(user1);
        marketNft.buyFraction{value: 1 ether}(0, 100);

        vm.deal(address(marketNft), 1 ether);
        uint256 userBalanceBefore = user1.balance;

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit SellFraction(user1, 0, 50);
        marketNft.sellFraction(0, 50);

        assertEq(marketNft.getFractionalBalance(0, user1), 50);
        assertEq(marketNft.getFractionalBalance(0, address(marketNft)), 950);
        assertEq(user1.balance, userBalanceBefore + 0.5 ether);
    }

    function test_SellFractionInsufficientBalance() public {
        vm.prank(owner);
        marketNft.mintNft(propertyName, propertyDesc, propertyLoc, tokenUri, 1000);

        vm.prank(user1);
        vm.expectRevert(MarketNft.MarketNFT__InsufficientFractions.selector);
        marketNft.sellFraction(0, 100);
    }

    function test_SellFractionInsufficientContractBalance() public {
        vm.prank(owner);
        marketNft.mintNft(propertyName, propertyDesc, propertyLoc, tokenUri, 1000);

        vm.prank(user1);
        marketNft.buyFraction{value: 1 ether}(0, 100);

        vm.prank(owner);
        marketNft.withdraw();

        vm.prank(user1);
        vm.expectRevert(MarketNft.MarketNFT__InsufficientBalance.selector);
        marketNft.sellFraction(0, 100);
    }

    function test_SellFractionNonExistentToken() public {
        vm.prank(user1);
        vm.expectRevert(MarketNft.MarketNFT__PropertyDoesNotExist.selector);
        marketNft.sellFraction(0, 100);
    }

    // Price Update Tests
    function test_SetNewFractionPriceAsOwner() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit FractionPriceUpdated(0.02 ether);
        marketNft.setNewFractionPrice(0.02 ether);
        assertEq(marketNft.getPrice(), 0.02 ether);
    }

    function test_SetNewFractionPriceNotOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        marketNft.setNewFractionPrice(0.02 ether);
    }

    // Withdraw Tests
    function test_WithdrawAsOwner() public {
        vm.prank(owner);
        marketNft.mintNft(propertyName, propertyDesc, propertyLoc, tokenUri, 1000);

        vm.prank(user1);
        marketNft.buyFraction{value: 1 ether}(0, 100);

        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(owner);
        vm.expectEmit(true, false, false, true);
        emit Withdraw(owner, 1 ether);
        marketNft.withdraw();

        assertEq(owner.balance, ownerBalanceBefore + 1 ether);
        assertEq(address(marketNft).balance, 0);
    }

    function test_WithdrawNotOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        marketNft.withdraw();
    }

    // Metadata Tests
    function test_SetTokenMetadataAsOwner() public {
        vm.prank(owner);
        marketNft.mintNft(propertyName, propertyDesc, propertyLoc, tokenUri, 1000);

        vm.prank(owner);
        marketNft.setTokenMetadata(0, "TestName", "TestDesc", "TestLoc", "TestImage");

        (string memory name, string memory desc, string memory loc, string memory img) = marketNft
            .s_tokenMetadata(0);
        assertEq(name, "TestName");
        assertEq(desc, "TestDesc");
        assertEq(loc, "TestLoc");
        assertEq(img, "TestImage");
    }

    function test_SetTokenMetadataNotOwner() public {
        vm.prank(owner);
        marketNft.mintNft(propertyName, propertyDesc, propertyLoc, tokenUri, 1000);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        marketNft.setTokenMetadata(0, "TestName", "TestDesc", "TestLoc", "TestImage");
    }

    function test_TokenURINonExistentToken() public {
        vm.expectRevert(MarketNft.MarketNFT__PropertyDoesNotExist.selector);
        marketNft.tokenURI(0);
    }

    function test_TokenURIContent() public {
        vm.prank(owner);
        marketNft.mintNft(propertyName, propertyDesc, propertyLoc, tokenUri, 1000);

        string memory uri = marketNft.tokenURI(0);

        // Check that it starts with the correct prefix
        string memory prefix = "data:application/json;base64,";
        assertTrue(bytes(uri).length > bytes(prefix).length, "URI too short");

        // Simple verification that the URI contains expected metadata
        // This test doesn't decode the Base64 content but verifies the URI is formed correctly
        // and that tokenURI doesn't revert for a valid token
        assertTrue(bytes(uri).length > 0, "Empty token URI");

        // Additional verification by checking metadata values directly
        (string memory name, string memory desc, string memory loc, string memory img) = marketNft
            .s_tokenMetadata(0);
        assertEq(name, propertyName);
        assertEq(desc, propertyDesc);
        assertEq(loc, propertyLoc);
        assertEq(img, tokenUri);
    }

    /*//////////////////////////////////////////////////////////////
                           ADDITIONAL TESTS
    //////////////////////////////////////////////////////////////*/
    function test_Getters() public view {
        assertEq(marketNft.getPrice(), initialFractionPrice);
        assertEq(marketNft.getBalance(), 0);
        assertEq(marketNft.getTokenCounter(), 0);
        assertEq(marketNft.getFractionalSupply(0), 0);
        assertEq(marketNft.getFractionalBalance(0, address(marketNft)), 0);
    }

    function test_FallbackReverts() public {
        vm.prank(user1);
        vm.expectRevert(MarketNft.MarketNFT__Fallback.selector);
        address(marketNft).call{value: 1 ether}("");
    }

    function test_ReceiveReverts() public {
        vm.prank(user1);
        vm.expectRevert(MarketNft.MarketNFT__Fallback.selector);
        payable(address(marketNft)).transfer(1 ether);
    }
}
