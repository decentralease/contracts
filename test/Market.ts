import {expect} from 'chai';
import {ethers} from 'hardhat';

import {loadFixture} from '@nomicfoundation/hardhat-network-helpers';

const NULL_ADDR = "0x0000000000000000000000000000000000000000";
const millis = 1757251504784;


describe("place market order", function () {

    async function setup() {
        const [owner, addr1] = await ethers.getSigners();

        const ERC = await ethers.getContractFactory("ERC4907");
        const Complex = await ethers.getContractFactory("ComplexDoNFT");
        const Market = await ethers.getContractFactory("Market");

        const dErc = await ERC.deploy("S", "S");
        const dComplex = await Complex.deploy();
        const dMarket = await Market.deploy();

        await dComplex.initialize("S", "S", dErc.address, dMarket.address, owner.address, owner.address, owner.address);
        await dMarket.initialize(owner.address, owner.address);

        return {
            owner,
            addr1,
            erc: dErc,
            complex: dComplex,
            market: dMarket
        }
    }


    it("Deployment should assign the total supply of tokens to the owner", async function () {
        const {owner, addr1, erc, complex, market} = await loadFixture(setup);

        await erc.mint(owner.address, 1);
        await erc.setApprovalForAll(complex.address, true);

        const oid = 1;
        await complex.mintVNft(oid);
        const vid = await complex.getVNftId(oid);

        expect(await complex.ownerOf(vid)).to.equal(owner.address);
        expect(await erc.ownerOf(oid)).to.equal(complex.address);

        const oneEth = ethers.utils.parseEther("1");


        const prices = [oneEth, oneEth];
        const durations = [0, 1];

        const rentingTime = 11;


        await market.createSigma(complex.address, vid, NULL_ADDR, prices, durations, millis);
        const x = await market.getPaymentSigma(complex.address, vid);
        expect(x.token).to.equal(NULL_ADDR);
        expect(x.infos.map(({minDuration}) => minDuration)).to.deep.equal(durations);
        expect(x.infos.map(({pricePerDay}) => pricePerDay)).to.deep.equal(prices);

        const orderTime = Math.ceil(Date.now() / 1000);
        await market.connect(addr1).fulfillOrderNow(complex.address, 1, 1, rentingTime, addr1.address,
            {value: oneEth});

        expect(await erc.userOf(oid)).to.equal(addr1.address);
        expect(Math.abs((await erc.userExpires(oid)).toNumber() - (orderTime + rentingTime))).to.lt(10);

        console.log("waiting for rental period to expire...");
        await new Promise(res => setTimeout(res, 2 * rentingTime * 1000));
        console.log("continuing");

        const dlist = await complex.getDurationIdList(vid);
        await complex.redeem(vid, dlist);
        expect(await erc.ownerOf(oid)).to.equal(owner.address);
    });
});