import React, { useEffect, useState } from 'react'
import { useEthers, useEtherBalance, Mainnet } from "@usedapp/core";
import { Network, Alchemy } from "alchemy-sdk"
import Box from '@mui/material/Box';
import SellNFTCard from './SellNFTCard.js'
import Grid from '@mui/material/Grid';

function ViewNFTPage() {

    const { account } = useEthers()
    const [nfts, setNfts] = useState([])
    // const axios = require("axios");
    // const options = {
    //     method: 'GET',
    //     url: 'https://opensea15.p.rapidapi.com/api/v1/assets',
    //     params: {owner: `${account}`},
    //     headers: {
    //       'X-RapidAPI-Key': '73764aa404msh6e5e4f2abf95983p14f036jsna93351c64534',
    //       'X-RapidAPI-Host': 'opensea15.p.rapidapi.com'
    //     }
    // };

    // const getNftData = async() => {
    //     await axios.request(options).then(function (response) {
    //         const data = response.data
    //         setNfts(data.assets)
    //         // debugger
    //     }).catch(function (error) {
    //         console.error(error);
    //     });
    // }

    const settingsGetNft = {
        apiKey: "6RB8WVyUkqB6YjCiiKX57HqZL7RRiVYL", // Replace with your Alchemy API Key.
        network: Network.ETH_GOERLI, // Replace with your network.
    };

    const getNftData = () => {
        const alchemy = new Alchemy(settingsGetNft);
        alchemy.nft.getNftsForOwner(account).then(function (response) {
            const data = response.ownedNfts
            setNfts(data)
            // debugger
        }).catch(function (error) {
            console.error(error);
        });
    }

    useEffect(() => {
        getNftData()
    }, [account])

    return (
        <Box display="flex" justifyContent="center" alignItems="center" textAlign="center">

            <Box className='viewNFTContainer' display="inline-flex">
                <Grid container rowSpacing={1} columnSpacing={{ xs: 1, sm: 2, md: 3 }}>
                    {/* <div className='nft-container'> */}
                    {nfts.map((nft, index) => {
                        return <Grid item md={3} xs={12}>
                            <SellNFTCard nft={nft} key={index} />
                        </Grid>
                    })}
                    {/* </div> */}
                </Grid>
            </Box>

        </Box>

    )

}

export default ViewNFTPage;
