import * as React from 'react';
import { styled } from '@mui/material/styles';
import Grid from '@mui/material/Grid';
import Paper from '@mui/material/Paper';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Divider from '@mui/material/Divider';
import List from '@mui/material/List';
import { Link } from 'react-router-dom';

import VerticalAlignBottomIcon from '@mui/icons-material/VerticalAlignBottom';
import AddCircleOutlineIcon from '@mui/icons-material/AddCircleOutline';
import HistoryIcon from '@mui/icons-material/History';
import AccountBalanceWalletIcon from '@mui/icons-material/AccountBalanceWallet';
import AccountBalanceIcon from '@mui/icons-material/AccountBalance';
import NFTList from './NFTList.js'
import { Network, Alchemy } from "alchemy-sdk"

import { useEthers, useEtherBalance, useCall } from "@usedapp/core";
import { useEffect, useState } from 'react'
import { formatEther } from "ethers/lib/utils";

import Moment from 'react-moment';
import axios from 'axios';
import abi from '../contracts/Bank2/abi.json';
import ContractAddress from './ContractAddress.json'
import { Interface } from '@ethersproject/abi';
import { Contract } from '@ethersproject/contracts';

const Item = styled(Paper)(({ theme }) => ({
    backgroundColor: theme.palette.mode === 'dark' ? '#1A2027' : '#fff',
    height: '20rem',
    ...theme.typography.body2,
    padding: theme.spacing(2),
    textAlign: 'left',
    color: theme.palette.text.secondary,
    borderRadius: 40
}));


function HomePage() {
    const { account } = useEthers()
    const Balance = useEtherBalance(account, { refresh: 'never' })
    const [EthData, setEthData] = useState([])
    const [nfts, setNfts] = useState([])
    const link = "https://goerli.etherscan.io/address/" + account
    const [results, setResults] = useState([])
    const contractAddress = ContractAddress.bank;
    const ABI  = new Interface(abi);
    const { value } = useCall(account && contractAddress && {
        contract: new Contract(contractAddress, ABI),
        method: 'balanceOf',
        args: [account]
    }) ?? {};

    const depositBalance = value ? value[0] : 0;

    useEffect(() => {
        //Get ETH price data
        const ws = new WebSocket('wss://stream.binance.com:9443/ws/ethusdt@ticker')
        ws.onmessage = (event) => {
            const data = JSON.parse(event.data);
            // debugger
            setEthData(data)
        }

    }, [])

    useEffect(() => {
        const settings = {
            apiKey: "6RB8WVyUkqB6YjCiiKX57HqZL7RRiVYL", // Replace with your Alchemy API Key.
            network: Network.ETH_GOERLI, // Replace with your network.
        };
        const getNftData = () => {
            const alchemy = new Alchemy(settings);
            alchemy.nft.getNftsForOwner(account).then(function (response) {
                const data = response.ownedNfts
                setNfts(data)
                // debugger
            }).catch(function (error) {
                console.error(error);
            });
        }
        getNftData()
    }, [account])

    useEffect(() => {
        const apikey = "F8BTXW9R9QHDY2IUTMNDTZKGX423D7SYGV";
        const endpoint = "https://api-goerli.etherscan.io/api"
        axios
        .get(endpoint + `?module=account&action=txlist&address=${account}&apikey=${apikey}&sort=desc`)
        .then(response => setResults(response.data.result));
    }, [account, results]);

    return (
        <Box className='homePage'>
            <Grid container rowSpacing={1} columnSpacing={{ xs: 1, sm: 2, md: 3 }}>

                <Grid item md={4} xs={12}>
                    <Item style={{ height: "41rem" }}>
                        <div>
                            <AccountBalanceIcon className='homePageTitle' />
                            <div className='homePageFont1 homePageTitle'>My NFTs</div>
                            <div>&nbsp;Total ERC721 Token</div>
                        </div>
                        <Divider sx={{ borderBottomWidth: 5 }} />
                        <Box sx={{ height: "31rem" }}>
                            <List key='hi3'>
                                {nfts.map((nft, index) => {
                                    return index < 5 && <NFTList nft={nft} key={index} />
                                })}
                            </List>
                        </Box>
                        <Divider sx={{ borderBottomWidth: 5 }} />
                        <div className='bottomButtonContainer'>
                            <Button variant="contained" component={Link} to="/viewnft" style={{
                                borderRadius: 10, padding: "9px 18px", fontSize: "12px", margin: "12px 15px 10px 15px", width: "70%"
                            }}>
                                View My NFTs
                            </Button>
                        </div>
                    </Item>
                </Grid>

                <Grid item md={4} xs={12}>
                    <Grid container rowSpacing={2}>
                        <Grid item xs={12}>
                            <Item>
                                <div >
                                    <AddCircleOutlineIcon className='homePageTitle' />
                                    <div className='homePageFont1 homePageTitle'>My Account</div><br/>
                                    <div style={{ display: "inline-flex" }}>&nbsp;Total Balance</div>
                                    <div style={{ display: "inline-flex", float: "right" }}>{depositBalance? parseFloat(formatEther(depositBalance)).toFixed(4) : 0} ETH</div>
                                </div>
                                <Divider sx={{ borderBottomWidth: 5 }} />
                                <Box sx={{ height: "10rem", padding: "1rem" }}>
                                <Grid container rowSpacing={2}>
                                    <Grid item xs={8}>
                                        {Balance && <Box>Total value: </Box>}
                                        APR: <br />
                                        {Balance && <Box>Total interest: </Box>}
                                    </Grid>
                                    <Grid item xs={4}>
                                        {Balance && <Box>${depositBalance? (parseFloat(formatEther(depositBalance)).toFixed(4) * parseFloat(EthData.c).toFixed(2)).toFixed(4) : 0}</Box>}
                                        40.23 % <br />
                                        {Balance && <Box>0.1 ETH </Box>}
                                    </Grid>
                                </Grid>
                                </Box>
                                <Divider sx={{ borderBottomWidth: 5 }} />
                                <div className='bottomButtonContainer'>
                                    <Button variant="contained" component={Link} to="/deposit" style={{
                                        borderRadius: 10, padding: "9px 18px", fontSize: "12px", margin: "12px 15px 10px 15px", width: "40%"
                                    }}>
                                        Deposit ETH
                                    </Button>
                                    <Button variant="outlined" component={Link} to="/withdraw" style={{
                                        borderRadius: 10, padding: "9px 18px", fontSize: "12px", margin: "12px 15px 10px 15px", width: "40%"
                                    }}>
                                        Withdraw ETH
                                    </Button>
                                </div>
                            </Item>
                        </Grid>
                        <Grid item xs={12}>
                            <Item>
                                <div >
                                    <HistoryIcon className='homePageTitle' />
                                    <div className='homePageFont1 homePageTitle'>History</div>
                                    <div>&nbsp;Record</div>
                                </div>
                                <Divider sx={{ borderBottomWidth: 5 }} />
                                <Box sx={{ height: "10rem", padding: "1rem", paddingTop: 0 }}>
                                    <List key='hi'>
                                        <Grid container>
                                            <Grid item xs={3}>
                                                <div style={{ fontWeight: 'bolder' }}>Time</div>
                                            </Grid>
                                            <Grid item xs={6}>
                                                <div style={{ fontWeight: 'bolder' }}>Action</div>
                                            </Grid>
                                            <Grid item xs={3}>
                                                <div style={{ fontWeight: 'bolder' }}>Amount</div>
                                            </Grid>
                                        </Grid>
                                        {Object.values(results).map((result, index) => {
                                            return index < 3 && account && (
                                                <Grid container rowSpacing={2}>
                                                    <Grid item xs={3}>
                                                        <Moment unix format="YYYY/MM/DD">{result.timeStamp}</Moment>
                                                    </Grid>
                                                    <Grid item xs={6}>
                                                        {result.functionName}
                                                    </Grid>
                                                    <Grid item xs={3}>
                                                        {result.value ? parseFloat(formatEther(result.value)).toFixed(4) : 0} ETH
                                                    </Grid>
                                                </Grid>
                                            );
                                        })}
                                    </List>
                                </Box>
                                <Divider sx={{ borderBottomWidth: 5 }} />
                                <div className='bottomButtonContainer'>
                                    <Button variant="contained" component={Link} to="/history" style={{
                                        borderRadius: 10, padding: "9px 18px", fontSize: "12px", margin: "12px 15px 10px 15px", width: "70%"
                                    }}>
                                        View History
                                    </Button>
                                </div>
                            </Item>
                        </Grid>
                    </Grid>
                </Grid>
                <Grid item md={4} xs={12}>
                    <Grid container rowSpacing={2}>
                        <Grid item xs={12}>
                            <Item>
                                <div>
                                    <VerticalAlignBottomIcon className='homePageTitle' />
                                    <div className='homePageFont1 homePageTitle'>My Borrows</div><br/>
                                    <div style={{ display: "inline-flex" }}>&nbsp;Total Debt</div>
                                    <div style={{ display: "inline-flex", float: "right" }}>{depositBalance? parseFloat(formatEther(depositBalance)).toFixed(4) : 0} ETH</div>
                                </div>
                                <Divider sx={{ borderBottomWidth: 5 }} />
                                <Box sx={{ height: "10rem", padding: "1rem", paddingTop: 0 }}>
                                    <List key='hi2'>
                                        <Grid container>
                                            <Grid item xs={4}>
                                                <div style={{ fontWeight: 'bolder' }}>Name</div>
                                            </Grid>
                                            <Grid item xs={4}>
                                                <div style={{ fontWeight: 'bolder' }}>Price</div>
                                            </Grid>
                                            <Grid item xs={4}>
                                                <div style={{ fontWeight: 'bolder' }}>Outstanding loan</div>
                                            </Grid>
                                        </Grid>
                                        {Object.values(results).map((result, index) => {
                                            return index < 5 && account && (
                                                <Grid container rowSpacing={2}>
                                                    <Grid item xs={4}>
                                                        COMP4805
                                                    </Grid>
                                                    <Grid item xs={4}>
                                                        {result.value ? parseFloat(formatEther(result.value)).toFixed(4) + 1 : 0} ETH
                                                    </Grid>
                                                    <Grid item xs={4}>
                                                        {result.value ? parseFloat(formatEther(result.value)).toFixed(4) : 0} ETH
                                                    </Grid>
                                                </Grid>
                                            );
                                        })}
                                    </List>
                                </Box>
                                <Divider sx={{ borderBottomWidth: 5 }} />
                                <div className='bottomButtonContainer'>
                                    <Button variant="contained" component={Link} to="/marketplace" style={{
                                        borderRadius: 10, padding: "9px 18px", fontSize: "12px", margin: "12px 15px 10px 15px", width: "40%"
                                    }}>
                                        Borrow ETH
                                    </Button>
                                    <Button variant="outlined" component={Link} to="/viewnft" style={{
                                        borderRadius: 10, padding: "9px 18px", fontSize: "12px", margin: "12px 15px 10px 15px", width: "40%"
                                    }}>
                                        My Borrows
                                    </Button>
                                </div>
                            </Item>
                        </Grid>

                        <Grid item xs={12}>
                            <Item>
                                <div >
                                    <AccountBalanceWalletIcon className='homePageTitle' />
                                    <div className='homePageFont1 homePageTitle'>My Wallet</div>
                                    <div>&nbsp;{account}</div>
                                </div>
                                <Divider sx={{ borderBottomWidth: 5 }} />
                                <Box sx={{ height: "10rem", padding: "1rem" }}>
                                    <Grid container rowSpacing={2}>
                                        <Grid item xs={8}>
                                            {Balance && <Box>ETH Balance: </Box>}
                                            Ethereum Price: <br />
                                            24h Price Change: <br />
                                            24h Percentage Change: 
                                        </Grid>
                                        <Grid item xs={4}>
                                            {Balance && <Box>{parseFloat(formatEther(Balance)).toFixed(4)} Ξ</Box>}
                                            ${parseFloat(EthData.c).toFixed(2)} <br />
                                            ${parseFloat(EthData.p).toFixed(2)} <br />
                                            {parseFloat(EthData.P).toFixed(2)}%
                                        </Grid>
                                    </Grid>
                                </Box>
                                <Divider sx={{ borderBottomWidth: 5 }} />
                                <div className='bottomButtonContainer'>
                                    <Button variant="contained" style={{
                                        borderRadius: 10, padding: "9px 18px", fontSize: "12px", margin: "12px 15px 10px 15px", width: "70%"
                                    }} target="_blank" component="a" href={link}>
                                        View On Ethereum
                                    </Button>
                                </div>
                            </Item>
                        </Grid>

                    </Grid>
                </Grid>
            </Grid>
        </Box>
    );
}

export default HomePage;