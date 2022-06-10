const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("GameRegistry", () => {
  let addressRegistry, gameRegistry, tournamentCreationFeeToken, USDC, ARCD, Arcadian721, Arcadian1155;

  let game1 = "Game1",
    game2 = "Game2";

  // const ONE_ETHER = ethers.utils.parseEther("1");
  const tournamentCreationFeeAmount = 100;
  const platformFee = 100; // 10%
  const baseGameCreatorFee = 100;  // 10%
  const proposedGameCreatorFee = 150; // 15%
  const tournamentCreatorFee = 250; // 25%

  const ZERO_ADDRESS = ethers.constants.AddressZero;

  beforeEach(async () => {
    [deployer, alice, bob, carol, feeRecipient, token1, token2, token3] = await ethers.getSigners();

    // deploy mock ERC20 tokens
    const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    tournamentCreationFeeToken = await ERC20Mock.deploy("mockFeeToken", "mockFeeToken");
    USDC = await ERC20Mock.deploy("USDC", "USDC");
    ARCD = await ERC20Mock.deploy("ARCD", "ARCD");

    // deploy mock ERC721 tokens
    const mockERC721 = await ethers.getContractFactory("MockERC721");
    Arcadian721 = await mockERC721.deploy();

    // deploy mock ERC1155 tokens
    const mockERC1155 = await ethers.getContractFactory("MockERC1155");
    Arcadian1155 = await mockERC1155.deploy();

    // Initialize AddressRegistry contract
    const AddressRegistry = await ethers.getContractFactory("AddressRegistry");
    addressRegistry = await upgrades.deployProxy(AddressRegistry);

    // Initialize GameRegistry contract
    const GameRegistry = await ethers.getContractFactory("GameRegistry");
    gameRegistry = await upgrades.deployProxy(GameRegistry, [
      addressRegistry.address,
      feeRecipient.address,
      platformFee,
      tournamentCreationFeeToken.address,
      tournamentCreationFeeAmount,
    ]);
    
    // Initialize Oparcade contract
    const Oparcade = await ethers.getContractFactory("Oparcade");
    oparcade = await upgrades.deployProxy(Oparcade, [addressRegistry.address]);

    // Register the contracts to AddressRegistry
    await addressRegistry.updateGameRegistry(gameRegistry.address);
    await addressRegistry.updateOparcade(oparcade.address);

    // transfer mock ERC20 tokens to the users
    await tournamentCreationFeeToken.transfer(alice.address, 10000000);
    await USDC.transfer(alice.address, 10000000);
    await ARCD.transfer(alice.address, 10000000);

    await tournamentCreationFeeToken.transfer(bob.address, 10000000);
    await USDC.transfer(bob.address, 10000000);
    await ARCD.transfer(bob.address, 10000000);

    // transfer mock ERC721 tokens to the users
    await Arcadian721.mint(alice.address, 0);
    await Arcadian721.mint(alice.address, 1);
    await Arcadian721.mint(alice.address, 2);

    await Arcadian721.mint(bob.address, 4);
    await Arcadian721.mint(bob.address, 5);
    await Arcadian721.mint(bob.address, 6);

    // transfer mock ERC1155 tokens to the users
    await Arcadian1155.mint(alice.address, [0, 1, 2], [10, 10, 10]);
    await Arcadian1155.mint(bob.address, [0, 1, 2], [10, 10, 10]);
  });

  describe("addGame", async () => {
    it("Should be able to add a new game...", async () => {
      // add the first game
      await gameRegistry.addGame(game1, alice.address, baseGameCreatorFee);
      expect(await gameRegistry.games(0)).to.equal(game1);
      expect(await gameRegistry.isDeprecatedGame(0)).to.be.false;
      expect(await gameRegistry.gameCount()).to.equal(1);
  
      // add the second game
      await gameRegistry.addGame(game2, bob.address, baseGameCreatorFee);
      expect(await gameRegistry.games(1)).to.equal(game2);
      expect(await gameRegistry.isDeprecatedGame(1)).to.be.false;
      expect(await gameRegistry.gameCount()).to.equal(2);
    });
  
    it("Should revert if the game name is empty...", async () => {
      await expect(gameRegistry.addGame("", alice.address, baseGameCreatorFee)).to.be.revertedWith("Empty game name");
    });
  
    it("Should revert if the game creator address is zero address...", async () => {
      await expect(gameRegistry.addGame(game1, ZERO_ADDRESS, baseGameCreatorFee)).to.be.revertedWith("Zero game creator address");
    });
  
    it("Should revert if the base game creator fee is exceeded...", async () => {
      await expect(gameRegistry.addGame(game1, alice.address, 1000)).to.be.revertedWith("Exceeded base game creator fee");
    });
  });

  describe("removeGame", async () => {
    beforeEach(async () => {
      // add the first game
      await gameRegistry.addGame(game1, alice.address, baseGameCreatorFee);

      // add the second game
      await gameRegistry.addGame(game2, bob.address, baseGameCreatorFee);
    });

    it("Should revert if trying to remove a non-existing game...", async () => {
      const gid = 2;
  
      // remove the game
      await expect(gameRegistry.removeGame(gid)).to.be.revertedWith("Invalid game index");
    });
  
    it("Should be able to remove the game...", async () => {
      const gid = 0;
  
      // remove the first game
      await gameRegistry.removeGame(gid);
      expect(await gameRegistry.games(0)).to.equal(game1);
      expect(await gameRegistry.isDeprecatedGame(gid)).to.be.true;
    });
  });

  describe("updateGameCreator", async () => {
    beforeEach(async () => {
      // add the first game
      await gameRegistry.addGame(game1, alice.address, baseGameCreatorFee);

      // add the second game
      await gameRegistry.addGame(game2, bob.address, baseGameCreatorFee);
    });
  
    it("Should be able to update the game creator address...", async () => {
      const gid = 0;

      expect(await gameRegistry.gameCreators(gid)).to.equal(alice.address);

      // update the game creator address
      await gameRegistry.connect(alice).updateGameCreator(gid, carol.address);
      
      // check the game creator address updated
      expect(await gameRegistry.gameCreators(gid)).to.equal(carol.address);
    });

    it("Should revert if trying to update the game creator address of the non-existing game...", async () => {
      const gid = 2;
  
      // update the game creator address
      await expect(gameRegistry.connect(alice).updateGameCreator(gid, carol.address)).to.be.revertedWith("Invalid game index");
    });

    it("Should revert if msg.sender is not the game creator...", async () => {
      const gid = 0;
  
      // update the game creator address
      await expect(gameRegistry.connect(bob).updateGameCreator(gid, carol.address)).to.be.revertedWith("Only game creator");
    });

    it("Should revert if the new game creator address is zero...", async () => {
      const gid = 0;
  
      // update the game creator address
      await expect(gameRegistry.connect(alice).updateGameCreator(gid, ZERO_ADDRESS)).to.be.revertedWith("Zero game creator address");
    });
  });

  describe("updateBaseGameCreatorFee", async () => {
    beforeEach(async () => {
      // add the first game
      await gameRegistry.addGame(game1, alice.address, baseGameCreatorFee);

      // add the second game
      await gameRegistry.addGame(game2, bob.address, baseGameCreatorFee);
    });
  
    it("Should be able to update the base game creator fee...", async () => {
      const gid = 0;
      const newGameCreatorFee = 200;

      expect(await gameRegistry.baseGameCreatorFees(gid)).to.equal(baseGameCreatorFee);

      // update the game creator address
      await gameRegistry.updateBaseGameCreatorFee(gid, newGameCreatorFee);
      
      // check the game creator address updated
      expect(await gameRegistry.baseGameCreatorFees(gid)).to.equal(newGameCreatorFee);
    });

    it("Should revert if trying to update the base game creator fee of the non-existing game...", async () => {
      const gid = 2;
      const newGameCreatorFee = 200;
  
      // remove the game
      await expect(gameRegistry.updateBaseGameCreatorFee(gid, newGameCreatorFee)).to.be.revertedWith("Invalid game index");
    });

    it("Should revert if msg.sender is not the owner...", async () => {
      const gid = 0;
      const newGameCreatorFee = 200;
  
      // remove the game
      await expect(gameRegistry.connect(alice).updateBaseGameCreatorFee(gid, newGameCreatorFee)).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should revert if trying to update the base game creator fee is exceeded...", async () => {
      const gid = 0;
      const newGameCreatorFee = 1000;
  
      // remove the game
      await expect(gameRegistry.updateBaseGameCreatorFee(gid, newGameCreatorFee)).to.be.revertedWith("Exceeded game creator fee");
    });
  });

  describe("createTournamentByDAO", async () => {
    beforeEach(async () => {
      // add the first game
      await gameRegistry.addGame(game1, alice.address, baseGameCreatorFee);

      // add the second game
      await gameRegistry.addGame(game2, bob.address, baseGameCreatorFee);
    });

    it("Should be able to creator the tournament...", async () => {
      const gid = 0;

      expect(await gameRegistry.getTournamentCount(gid)).to.equal(0);

      // create the first tournament
      let tid = await gameRegistry.callStatic.createTournamentByDAO(gid, proposedGameCreatorFee, tournamentCreatorFee);
      await gameRegistry.createTournamentByDAO(gid, proposedGameCreatorFee, tournamentCreatorFee);
      
      // check the created tournament info
      expect(await gameRegistry.getTournamentCount(gid)).to.equal(1);
      expect(await gameRegistry.getTournamentCreator(gid, tid)).to.equal(deployer.address);
      expect(await gameRegistry.appliedGameCreatorFees(gid, tid)).to.equal(proposedGameCreatorFee);
      expect(await gameRegistry.tournamentCreatorFees(gid, tid)).to.equal(tournamentCreatorFee);

      // create the second tournament with the zero proposedGameCreatorFee
      tid = await gameRegistry.callStatic.createTournamentByDAO(gid, 0, tournamentCreatorFee);
      await gameRegistry.createTournamentByDAO(gid, 0, tournamentCreatorFee + 1);
      
      // check the created tournament info
      expect(await gameRegistry.getTournamentCount(gid)).to.equal(2);
      expect(await gameRegistry.getTournamentCreator(gid, tid)).to.equal(deployer.address);
      expect(await gameRegistry.appliedGameCreatorFees(gid, tid)).to.equal(baseGameCreatorFee);
      expect(await gameRegistry.tournamentCreatorFees(gid, tid)).to.equal(tournamentCreatorFee + 1);
    });

    it("Revert if msg.sender is not the owner...", async () => {
      const gid = 2;

      // create the tournament
      await expect(gameRegistry.connect(alice).createTournamentByDAO(gid, proposedGameCreatorFee, tournamentCreatorFee)).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Revert if the game doesn't exist...", async () => {
      const gid = 2;

      // create the tournament
      await expect(gameRegistry.createTournamentByDAO(gid, proposedGameCreatorFee, tournamentCreatorFee)).to.be.revertedWith("Invalid game index");
    });

    it("Revert if the proposed game creator fee is less than the base one...", async () => {
      const gid = 0;

      // create the tournament
      await expect(gameRegistry.createTournamentByDAO(gid, baseGameCreatorFee - 1, tournamentCreatorFee)).to.be.revertedWith("Low game creator fee proposed");
    });

    it("Revert if total fee is equal to or greater than 100%...", async () => {
      const gid = 0;

      // create the tournament
      await expect(gameRegistry.createTournamentByDAO(gid, 1000, tournamentCreatorFee)).to.be.revertedWith("Exceeded fees");
    });
  });

  describe("createTournamentByUser", async () => {
    beforeEach(async () => {
      // add the first game
      await gameRegistry.addGame(game1, alice.address, baseGameCreatorFee);

      // add the second game
      await gameRegistry.addGame(game2, bob.address, baseGameCreatorFee);
    });

    it("Should be able to creator the tournament with ERC20 and ERC721 prize pools...", async () => {
      const gid = 0;
      const depositTokenAddress = USDC;
      const depositTokenAmount = 100;
      const tokenToAddPrizePool = ARCD;
      const amountToAddPrizePool = 10000;
      const nftAddressToAddPrizePool = Arcadian721;
      const nftTypeToAddPrizePool = 721;
      const tokenIdsToAddPrizePool = [0, 1, 2];
      const amountsToAddPrizePool = [1, 1, 1];

      expect(await gameRegistry.getTournamentCount(gid)).to.equal(0);

      // approve tournamentCreationFeeToken and prize tokens to GameRegistry
      await tournamentCreationFeeToken.connect(alice).approve(gameRegistry.address, tournamentCreationFeeAmount);
      await tokenToAddPrizePool.connect(alice).approve(oparcade.address, amountToAddPrizePool);
      await nftAddressToAddPrizePool.connect(alice).approve(oparcade.address, tokenIdsToAddPrizePool[0]);
      await nftAddressToAddPrizePool.connect(alice).approve(oparcade.address, tokenIdsToAddPrizePool[1]);
      await nftAddressToAddPrizePool.connect(alice).approve(oparcade.address, tokenIdsToAddPrizePool[2]);

      // create the first tournament with ERC721
      let tid = await gameRegistry.connect(alice).callStatic.createTournamentByUser(gid, proposedGameCreatorFee, tournamentCreatorFee, depositTokenAddress.address, depositTokenAmount, tokenToAddPrizePool.address, amountToAddPrizePool, nftAddressToAddPrizePool.address, nftTypeToAddPrizePool, tokenIdsToAddPrizePool, amountsToAddPrizePool);
      await gameRegistry.connect(alice).createTournamentByUser(gid, proposedGameCreatorFee, tournamentCreatorFee, depositTokenAddress.address, depositTokenAmount, tokenToAddPrizePool.address, amountToAddPrizePool, nftAddressToAddPrizePool.address, nftTypeToAddPrizePool, tokenIdsToAddPrizePool, amountsToAddPrizePool);
      
      // check the created tournament info
      expect(await gameRegistry.getTournamentCount(gid)).to.equal(1);
      expect(await gameRegistry.getTournamentCreator(gid, tid)).to.equal(alice.address);
      expect(await gameRegistry.appliedGameCreatorFees(gid, tid)).to.equal(proposedGameCreatorFee);
      expect(await gameRegistry.tournamentCreatorFees(gid, tid)).to.equal(tournamentCreatorFee);
    });
  });

  // describe("updateDepositTokenAmount", async () => {
  //   beforeEach(async () => {
  //     // add the first game
  //     await gameRegistry.addGame(game1, alice.address, baseGameCreatorFee);

  //     // add the second game
  //     await gameRegistry.addGame(game2, bob.address, baseGameCreatorFee);
  //   });

  //   it("Should be able to update the deposit token...", async () => {
  //     const gid = 1;
  //     const tid0 = 0;
  //     const tid1 = 1;
  //     let depositTokenList = [];
  //     const token1_amount = 100;
  //     const token2_amount = 200;
  
  //     // add token1
  //     await gameRegistry.updateDepositTokenAmount(gid, tid0, token1.address, token1_amount);
  
  //     expect(await gameRegistry.depositTokenAmount(gid, tid0, token1.address)).to.equal(token1_amount);
  //     expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(1);
  //     expect(await gameRegistry.depositTokenList(gid, 0)).to.equal(token1.address);
  
  //     // update token1
  //     const new_token1_amount = 300;
  //     await gameRegistry.updateDepositTokenAmount(gid, tid0, token1.address, new_token1_amount);
  
  //     expect(await gameRegistry.depositTokenAmount(gid, tid0, token1.address)).to.equal(new_token1_amount);
  //     expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(1);
  //     expect(await gameRegistry.depositTokenList(gid, 0)).to.equal(token1.address);
  
  //     // add token2
  //     await gameRegistry.updateDepositTokenAmount(gid, tid1, token2.address, token2_amount);
  
  //     expect(await gameRegistry.depositTokenAmount(gid, tid1, token2.address)).to.equal(token2_amount);
  //     expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(2);
  //     expect(await gameRegistry.depositTokenList(gid, 1)).to.equal(token2.address);
  
  //     // remove token1
  //     await gameRegistry.updateDepositTokenAmount(gid, tid1, token1.address, 0);
  
  //     expect(await gameRegistry.depositTokenAmount(gid, tid1, token1.address)).to.equal(0);
  //     expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(1);
  //     expect(await gameRegistry.depositTokenList(gid, 0)).to.equal(token2.address);
  
  //     // remove token3 (unavailable token)
  //     await gameRegistry.updateDepositTokenAmount(gid, tid1, token3.address, 0);
  
  //     expect(await gameRegistry.depositTokenAmount(gid, tid1, token3.address)).to.equal(0);
  //     expect((await gameRegistry.getDepositTokenList(gid)).length).to.equal(1);
  //     expect(await gameRegistry.depositTokenList(gid, 0)).to.equal(token2.address);
  //   });
  // });

  // describe("updateDistributableTokenAddress", async () => {
  //   it("Should be able to update the distributable token...", async () => {
  //     const gid = 1;
  
  //     // add token1
  //     await gameRegistry.updateDistributableTokenAddress(gid, token1.address, true);
  
  //     expect((await gameRegistry.getDistributableTokenList(gid)).length).to.equal(1);
  //     expect(await gameRegistry.distributable(gid, token1.address)).to.be.true;
  
  //     // update token1
  //     await gameRegistry.updateDistributableTokenAddress(gid, token1.address, true);
  
  //     expect((await gameRegistry.getDistributableTokenList(gid)).length).to.equal(1);
  //     expect(await gameRegistry.distributable(gid, token1.address)).to.be.true;
  
  //     // add token2
  //     await gameRegistry.updateDistributableTokenAddress(gid, token2.address, true);
  
  //     expect((await gameRegistry.getDistributableTokenList(gid)).length).to.equal(2);
  //     expect(await gameRegistry.distributable(gid, token2.address)).to.be.true;
  
  //     // remove token2
  //     await gameRegistry.updateDistributableTokenAddress(gid, token2.address, false);
  
  //     expect((await gameRegistry.getDistributableTokenList(gid)).length).to.equal(1);
  //     expect(await gameRegistry.distributable(gid, token2.address)).to.be.false;
  //   });
  // });
});
