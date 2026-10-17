# Kyle’s parcel and order documents

After Summer leaves, the native Chapter 1 route can inspect Kyle’s parcel on the bed, collect the client list and read the order sheet. Both supplied walkthroughs identify this step. The detailed guide uses `CHP124`.

## Connected route

| Interaction | Original identifier |
| --- | --- |
| Bed inspection | R205 search area 2 |
| Kyle’s parcel | Subarea 3, model node `obj03`, event 113 |
| Parcel contents | Close-up 253, event 115 |
| Client list | Component 256, inventory item 49, shared search response |
| Order sheet | Component 254, event 118, inventory item 6 |

The native session uses normal movement and two presses per selected object. Client-list page coordinate `(65,135)` maps to DS touch coordinate `(120,65)`. Order-sheet page coordinate `(161,219)` maps to DS touch coordinate `(36,161)`.

The order sheet names the small red box and December magazine. The existing script handler awards the document and starts Kyle’s reminder to call Rachel. Collected document layers disappear through the existing inventory visibility rules. The sewing machine and adhesive remover remain visible.

## Original comparisons

`OriginalSearchCloseupTests` compares all 32,088 game-state bytes after opening the parcel, collecting the client list and reading the order sheet. It also compares the complete packed hit map and composited colour buffer at all three checkpoints. All comparisons pass.

The native route from hotel arrival through both document pickups also passes. Its bed approach continues until the inspection target is available. A fixed movement sequence copied from Louie’s earlier departure stopped short because Summer leaves Kyle at a different position.

The latest close-up run passed six tests. The preceding native-route and close-up run passed seven tests. These are overlapping runs, not thirteen distinct tests.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter OriginalSearchCloseupTests
SNAPSHOT_DIR=/tmp/hotel-order-documents DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter LayoutSnapshotTests.testRenderRequiredDunningQuestionsAndDeliveryKnock
```

| Local original checkpoint | SHA-256 |
| --- | --- |
| `order-parcel-open/page5.mln` | `919aa34fc05dc1307fdf736ce3b8a1209f43e1670ffcbdf4c09d20306fa5e6e2` |
| `order-client-list/page15.mln` | `fd39ec88bad2ce651088a0e79aa3a71e6b2d3dbf2218467c85f26e6a9d2eb2f3` |
| `order-sheet/page15.mln` | `03cda2de33b38de3564f7000418a94b8160bc375eefaf4052ba0fe96ae4bf7d4` |

Reference scripts are under `tools/reference/order-*.txt`. The checked captures continue the modified delivery fixture through Iris and Summer. They add no memory writes. A complete matching original route from a new game remains outstanding.

The exploratory `order-phone-approach` capture does not establish telephone inspection. The corrected `order-leave-parcel` script uses separate Back actions and reaches telephone inspection. See [Chapter 1 review](chapter-one-review.md).

## Next work

- Continue from the connected call and review to the Chapter 2 transition.
- Compare optional product inspection, alternate item order and repeated document selection.
- Check physical Duo input and presentation.

The full game remains unfinished.
