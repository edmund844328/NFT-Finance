import Navbar from './NavBar';
import Banner from './Banner';
import ConnectWallet from './ConnectWallet';
import ViewNFTPage from './ViewNFTPage';
import { useEthers, useEtherBalance, Mainnet } from "@usedapp/core";
function ViewNFT() {
  const { account } = useEthers()
  return (
    <div>
      <Navbar />
      <Banner type="ViewNFT"/>
      {
        account
          ?
          <ViewNFTPage />
          :
          <ConnectWallet />
      }
    </div>
  );
}

export default ViewNFT;
