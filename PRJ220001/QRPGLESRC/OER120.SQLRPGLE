000100220121**free
000200220121
000300220121//--------------------------------------------------------------------------------------------------
000400220121// Program Id:     OER120
000500220121// Author:         Fred Campbell
000600220121// Program Desc.:  Validate Order Ship to Address
000700220121// Date Created:   01/21/2022
000800220121//
000900220121// This program must be compiled with library ATI in the library list.
001000220121//
001100220121//--------------------------------------------------------------------------------------------------
001200220121// 1.000 01/21/2022 JTC Original Version
001300220121//--------------------------------------------------------------------------------------------------
001400220121
001500220121ctl-opt main(Main) option(*nodebugio:*srcstmt:*nounref) dftactgrp(*no) actgrp('RPC')
001600220121        bnddir('SQLERRORS':'ATIBND');
001700220121
001800220121/include qrpglesrc,checksqlpr
001900220121/include qrpglecpy,aticb
002000220121
002100220121// Order Header by hstats/hplntc
002200220121dcl-f orHeadLa disk usage(*update) qualified keyed usropn;
002300220121
002400220121// Order Lines by lordr#/lseqn#
002500220121dcl-f orLineLa disk usage(*update) qualified keyed usropn;
002600220121
002700220121// Ship To Addresses by shcust/shaddr (omit deleted)
002800220121dcl-f oelsh01a disk usage(*update) qualified keyed usropn;
002900220121
003000220121// Order Ship To Addresses by shordr
003100220121dcl-f oepsh02 disk usage(*update) qualified keyed usropn;
003200220121
003300220121// Customer Master by cnbr
003400220121dcl-f ocusmas disk usage(*update) qualified keyed usropn;
003500220121
003600220121// Order Address Validation by ordNbr/reqId
003700220121dcl-f ordAdrVal disk usage(*input:*output) qualified keyed usropn;
003800220121
003900220121// ATI Address Request by uid
004000220121dcl-f atiAdrReq disk usage(*input:*output) qualified keyed alias usropn;
004100220121
004200220121// ATI Address Response by uid
004300220121dcl-f atiAdrRsp disk usage(*input) qualified keyed alias usropn;
004400220121
004500220121// ATI Address Response Candidates by pid/uid
004600220121dcl-f atiCanDs disk usage(*input) qualified keyed alias usropn;
004700220121
004800220121dcl-ds ordHeadDs_t likerec(orHeadLa.or1headr:*all) template;
004900220121dcl-ds ordLineDs_t likerec(orLineLa.or1liner:*all) template;
005000220121dcl-ds shipToAdrDs_t likerec(oelsh01a.sh01r1:*all) template;
005100220121dcl-ds ordShipToAdrDs_t likerec(oepsh02.sh02r1:*all) template;
005200220121dcl-ds cusMasDs_t likerec(ocusmas.cu1mas:*all) template;
005300220121dcl-ds ordAdrValDs_t likerec(ordAdrVal.ordAdrValR:*all) template;
005400220121dcl-ds atiAdrReqDs_t likerec(atiAdrReq.rAtiAdrReq:*all) template;
005500220121dcl-ds atiAdrRspDs_t likerec(atiAdrRsp.rAtiAdrRsp:*input) template;
005600220121dcl-ds atiAdrCanDs_t likerec(atiCanDs.rAtiCanDs:*input) template;
005700220121
005800220121dcl-ds ordAdrToValDs_t qualified template;
005900220121  hordr# char(8);
006000220121  hcust# char(6);
006100220121  hsovrc char(1);
006200220121  hsaddr zoned(4:0);
006300220121  hsadr1 char(28);
006400220121  hsadr2 char(28);
006500220121  hscity char(20);
006600220121  hsstte char(2);
006700220121  hszipc char(9);
006800220121  hsname char(28);
006900220121end-ds;
007000220121
007100220121dcl-proc Main;
007200220121  dcl-ds ordAdrToValDs likeds(ordAdrToValDs_t);
007300220121  dcl-ds ordAdrValDs likeds(ordAdrValDs_t);
007400220121  dcl-ds atiErrorDs likeds(ati_errorDs_t);
007500220121  dcl-ds atiAdrRspDs likeds(atiAdrRspDs_t);
007600220121  dcl-ds atiAdrCanDs likeds(atiAdrCanDs_t);
007700220121
007800220121  dcl-s lastRow ind;
007900220121  dcl-s atiReqId like(ati_uniqueId_t);
008000220121  dcl-s atiConfigId like(ati_configId_t) Inz(ATI_DEFAULT);
008100220121  dcl-s errMsg like(ati_errorDs_t.message);
008200220121
008300220121  dcl-c WAITING_FOR_AUTH 'A';
008400220121
008500220121  OpenCursor();
008600220121  OpenFiles();
008700220121
008800220121  dou lastRow;
008900220121    exec sql fetch next from OrdAdrToValCursor into :ordAdrToValDs;
009000220121    lastRow = Check_SQLState();
009100220121    if lastRow;
009200220121      leave;
009300220121    endif;
009400220121
009500220121    if ordAdrToValDs.hsovrc = 'N' and ordAdrToValDs.hsaddr = 9999;
009600220121      GetCusMasAdr(ordAdrToValDs);
009700220121    endif;
009800220121
009900220121    if not UsaAdr(ordAdrToValDs.hsstte);
010000220121      iter;
010100220121    endif;
010200220121
010300220121    ordAdrValDs = FindPrevAdrValReq(ordAdrToValDs);
010400220121    if ordAdrValDs.reqId <> 0;
010500220121      if ordAdrValDs.errMsg <> '';
010600220121        SetOrdSts(ordAdrValDs.ordNbr:WAITING_FOR_AUTH);
010700220121      endif;
010800220121      iter;
010900220121    endif;
011000220121
011100220121    ordAdrValDs = FindPrevAdrValRsp(ordAdrToValDs);
011200220121    if ordAdrValDs.reqId <> 0;
011300220121      if ordAdrValDs.errMsg <> '' and
011400220121         ordAdrValDs.errMsg <> 'Candidate address returned has address line longer than 28' and
011500220121         ordAdrValDs.errMsg <> 'Candidate address returned has no address line 2 but existing address does' and
011600220121         ordAdrValDs.errMsg <> 'Error updating ship to address';
011700220121        SetOrdSts(ordAdrValDs.ordNbr:WAITING_FOR_AUTH);
011800220121      endif;
011900220121      iter;
012000220121    endif;
012100220121
012200220121    atiReqId = Ati_getUniqueId();
012300220121    WriteAdrValReq(atiReqId:ordAdrToValDs);
012400220121    reset atiErrorDs;
012500220121    errMsg = '';
012600220121
012700220121    if Ati_validateStreet(atiReqId:atiConfigId:atiErrorDs);
012800220121      chain atiReqId atiAdrRsp.rAtiAdrRsp atiAdrRspDs;
012900220121      if %found(atiAdrRsp);
013000220121        if atiAdrRspDs.candidatesReturned <= 0;
013100220121          errMsg = 'No candidate address returned';
013200220121        elseif atiAdrRspDs.candidatesReturned = 1;
013300220121          chain atiReqId atiCanDs.rAtiCanDs atiAdrCanDs;
013400220121          if %found(atiCanDs);
013500220121            if %len(atiAdrCanDs.deliveryLine1) > 28 or
013600220121               %len(atiAdrCanDs.deliveryLine2) > 28;
013700220121              errMsg = 'Candidate address returned has address line longer than 28';
013800220121            elseif atiAdrCanDs.deliveryLine2 = '' and ordAdrToValDs.hsadr2 <> ' ';
013900220121              errMsg = 'Candidate address returned has no address line 2 but existing address does';
014000220121            else;
014100220121              if ordAdrToValDs.hsovrc = 'N' and ordAdrToValDs.hsaddr = 9999;
014200220121                if not UpdateCustAdr(ordAdrToValDs.hcust#:atiAdrCanDs);
014300220121                  errMsg = 'Error updating ship to address';
014400220121                endif;
014500220121              else;
014600220121                if ordAdrToValDs.hsovrc = 'N';
014700220121                  if not UpdateShipToAdr(ordAdrToValDs.hcust#:ordAdrToValDs.hsaddr:atiAdrCanDs);
014800220121                    errMsg = 'Error updating ship to address';
014900220121                  endif;
015000220121                else;
015100220121                  if not UpdateOrdShipToAdr(ordAdrToValDs.hordr#:atiAdrCanDs);
015200220121                    errMsg = 'Error updating ship to address';
015300220121                  endif;
015400220121                endif;
015500220121
015600220121                if not UpdateOrdHdrShipToAdr(ordAdrToValDs.hordr#:atiAdrCanDs);
015700220121                  errMsg = 'Error updating ship to address';
015800220121                endif;
015900220121              endif;
016000220121
016100220121              if not UpdateOrdLinShipToAdr(ordAdrToValDs.hordr#:atiAdrCanDs);
016200220121                errMsg = 'Error updating ship to address';
016300220121              endif;
016400220121            endif;
016500220121          else;
016600220121            errMsg = 'Candidate address not found';
016700220121          endif;
016800220121        else;
016900220121          errMsg = 'Multiple candidate addresses returned';
017000220121        endif;
017100220121      else;
017200220121        errMsg = 'Address validation response not found';
017300220121      endif;
017400220121    else;
017500220121      errMsg = atiErrorDs.message;
017600220121    endif;
017700220121
017800220121    WriteOrdAdrVal(ordAdrToValDs.hordr#:atiReqId:errMsg);
017900220121
018000220121    if errMsg <> '';
018100220121      SetOrdSts(ordAdrToValDs.hordr#:WAITING_FOR_AUTH);
018200220121    endif;
018300220121  enddo;
018400220121
018500220121  exec sql close OrdAdrToValCursor;
018600220121  close *all;
018700220121end-proc;
018800220121
018900220121//--------------------------------------------------------------------------------------------------
019000220121// OpenCursor(): Open a cursor to get the orders released today
019100220121//--------------------------------------------------------------------------------------------------
019200220121
019300220121dcl-proc OpenCursor;
019400220121  dcl-s currentDate char(10);
019500220121
019600220121  currentDate = %char(%date():*iso);
019700220121
019800220121  exec sql declare OrdAdrToValCursor cursor for
019900220121    select hordr#, hcust#, hsovrc, hsaddr, hsadr1, hsadr2, hscity, hsstte, hszipc, hsname
020000220121    from orheadla
020100220121    where hstats = 'B' and  hdbcrc = ' ' and hcust# <> '900500' and hsstte <> 'EX' and horig# = ' '
020200220121    order by hordr#
020300220121    limit 32;
020400220121
020500220121  exec sql open OrdAdrToValCursor;
020600220121
020700220121  Check_SQLState();
020800220121
020900220121  return;
021000220121end-proc;
021100220121
021200220121//--------------------------------------------------------------------------------------------------
021300220121// OpenFiles(): Open the files used by this program
021400220121//--------------------------------------------------------------------------------------------------
021500220121
021600220121dcl-proc OpenFiles;
021700220121
021800220121  if not %open(orHeadLa);
021900220121    open orHeadLa;
022000220121  endif;
022100220121
022200220121  if not %open(orLineLa);
022300220121    open orLineLa;
022400220121  endif;
022500220121
022600220121  if not %open(oelsh01a);
022700220121    open oelsh01a;
022800220121  endif;
022900220121
023000220121  if not %open(oepsh02);
023100220121    open oepsh02;
023200220121  endif;
023300220121
023400220121  if not %open(ocusmas);
023500220121    open ocusmas;
023600220121  endif;
023700220121
023800220121  if not %open(ordAdrVal);
023900220121    open ordAdrVal;
024000220121  endif;
024100220121
024200220121  if not %open(atiAdrReq);
024300220121    open atiAdrReq;
024400220121  endif;
024500220121
024600220121  if not %open(atiAdrRsp);
024700220121    open atiAdrRsp;
024800220121  endif;
024900220121
025000220121  if not %open(atiCanDs);
025100220121    open atiCanDs;
025200220121  endif;
025300220121
025400220121end-proc;
025500220121
025600220121//--------------------------------------------------------------------------------------------------
025700220121// GetCusMasAdr(): Get the customer master address
025800220121//--------------------------------------------------------------------------------------------------
025900220121
026000220121dcl-proc GetCusMasAdr;
026100220121  dcl-pi GetCusMasAdr;
026200220121    ordAdrToValDs likeds(ordAdrToValDs_t);
026300220121  end-pi;
026400220121
026500220121  dcl-ds cusMasDs likeds(cusMasDs_t);
026600220121
026700220121  chain(n) (ordAdrToValDs.hcust#) ocusmas.cu1mas cusMasDs;
026800220121  if %found(ocusmas);
026900220121    ordAdrToValDs.hsadr1 = cusMasDs.caddr1;
027000220121    ordAdrToValDs.hsadr2 = cusMasDs.caddr2;
027100220121    ordAdrToValDs.hscity = cusMasDs.ccity;
027200220121    ordAdrToValDs.hsstte = cusMasDs.cstate;
027300220121    ordAdrToValDs.hszipc = cusMasDs.zip5 + cusMasDs.zip4;
027400220121    ordAdrToValDs.hsname = cusMasDs.cname;
027500220121  endif;
027600220121end-proc;
027700220121
027800220121//--------------------------------------------------------------------------------------------------
027900220121// UsaAdr(): Determine if ship to address is a USA address.
028000220121//           Return *on if it is, otherwise *off.
028100220121//--------------------------------------------------------------------------------------------------
028200220121
028300220121dcl-proc UsaAdr;
028400220121  dcl-pi UsaAdr ind;
028500220121    hsstte like(ordAdrToValDs_t.hsstte) const;
028600220121  end-pi;
028700220121
028800220121  if hsstte = ' ';
028900220121    return *off;
029000220121  endif;
029100220121
029200220121  return *on;
029300220121end-proc;
029400220121
029500220121//--------------------------------------------------------------------------------------------------
029600220121// FindPrevAdrValReq(): Find a previous address validation request for this order with the same
029700220121//                      address.  If this routine finds a previous address validation request
029800220121//                      for the same order and address, it will return the request ID.  Otherwise,
029900220121//                      it will return zero.
030000220121//--------------------------------------------------------------------------------------------------
030100220121
030200220121dcl-proc FindPrevAdrValReq;
030300220121  dcl-pi FindPrevAdrValReq like(ordAdrValDs_t);
030400220121    ordAdrToValDs likeds(ordAdrToValDs_t) const;
030500220121  end-pi;
030600220121
030700220121  dcl-ds rtnOrdAdrValDs likeds(ordAdrValDs_t);
030800220121  dcl-ds ordAdrValDs likeds(ordAdrValDs_t);
030900220121  dcl-ds atiAdrReqDs likeds(atiAdrReqDs_t);
031000220121
031100220121  clear rtnOrdAdrValDs;
031200220121  setgt (ordAdrToValDs.hordr#) ordAdrVal.ordAdrValR;
031300220121  readpe (ordAdrToValDs.hordr#) ordAdrVal.ordAdrValR ordAdrValDs;
031400220121  if not %eof(ordAdrVal);
031500220121    chain (ordAdrValDs.reqId) atiAdrReq.rAtiAdrReq atiAdrReqDs;
031600220121    if %found(atiAdrReq);
031700220121      if atiAdrReqDs.street = %trim(ordAdrToValDs.hsadr1) and
031800220121         atiAdrReqDs.secondaryInfo = %trim(ordAdrToValDs.hsadr2) and
031900220121         atiAdrReqDs.city = %trim(ordAdrToValDs.hscity) and
032000220121         atiAdrReqDs.state = %trim(ordAdrToValDs.hsstte) and
032100220121         atiAdrReqDs.zipCode = %trim(ordAdrToValDs.hszipc);
032200220121        rtnOrdAdrValDs = ordAdrValDs;
032300220121      endif;
032400220121    endif;
032500220121  endif;
032600220121
032700220121  return rtnOrdAdrValDs;
032800220121end-proc;
032900220121
033000220121//--------------------------------------------------------------------------------------------------
033100220121// FindPrevAdrValRsp(): Find a previous address validation response for this order with the same
033200220121//                      address.  If this routine finds a previous address validation response
033300220121//                      for the same order and address, it will return the request ID.  Otherwise,
033400220121//                      it will return zero.
033500220121//--------------------------------------------------------------------------------------------------
033600220121
033700220121dcl-proc FindPrevAdrValRsp;
033800220121  dcl-pi FindPrevAdrValRsp like(ordAdrValDs_t);
033900220121    ordAdrToValDs likeds(ordAdrToValDs_t) const;
034000220121  end-pi;
034100220121
034200220121  dcl-ds rtnOrdAdrValDs likeds(ordAdrValDs_t);
034300220121  dcl-ds ordAdrValDs likeds(ordAdrValDs_t);
034400220121  dcl-ds atiAdrRspDs likeds(atiAdrRspDs_t);
034500220121  dcl-ds atiAdrCanDs likeds(atiAdrCanDs_t);
034600220121
034700220121  clear rtnOrdAdrValDs;
034800220121  setgt (ordAdrToValDs.hordr#) ordAdrVal.ordAdrValR;
034900220121  readpe (ordAdrToValDs.hordr#) ordAdrVal.ordAdrValR ordAdrValDs;
035000220121  if not %eof(ordAdrVal);
035100220121    chain (ordAdrValDs.reqId) atiAdrRsp.rAtiAdrRsp atiAdrRspDs;
035200220121    if %found(atiAdrRsp);
035300220121      if atiAdrRspDs.candidatesReturned = 1;
035400220121        chain ordAdrValDs.reqId atiCanDs.rAtiCanDs atiAdrCanDs;
035500220121        if %found(atiCanDs);
035600220121          if atiAdrCanDs.deliveryLine1 = %trim(ordAdrToValDs.hsadr1) and
035700220121             atiAdrCanDs.deliveryLine2 = %trim(ordAdrToValDs.hsadr2) and
035800220121             atiAdrCanDs.cityName = %trim(ordAdrToValDs.hscity) and
035900220121             atiAdrCanDs.stateAbbreviation = %trim(ordAdrToValDs.hsstte) and
036000220121             atiAdrCanDs.zipCode + atiAdrCanDs.plus4Code = %trim(ordAdrToValDs.hszipc);
036100220121            rtnOrdAdrValDs = ordAdrValDs;
036200220121          elseif %len(atiAdrCanDs.deliveryLine1) > 28 or
036300220121                 %len(atiAdrCanDs.deliveryLine2) > 28;
036400220121            rtnOrdAdrValDs = ordAdrValDs;
036500220121          endif;
036600220121        endif;
036700220121      endif;
036800220121    endif;
036900220121  endif;
037000220121
037100220121  return rtnOrdAdrValDs;
037200220121end-proc;
037300220121
037400220121//--------------------------------------------------------------------------------------------------
037500220121// WriteAdrValReq(): Write an address validation request record
037600220121//--------------------------------------------------------------------------------------------------
037700220121
037800220121dcl-proc WriteAdrValReq;
037900220121  dcl-pi WriteAdrValReq;
038000220121    atiReqId like(ati_uniqueId_t) const;
038100220121    ordAdrToValDs likeds(ordAdrToValDs_t) const;
038200220121  end-pi;
038300220121
038400220121  dcl-ds atiAdrReqDs likeds(atiAdrReqDs_t);
038500220121
038600220121  atiAdrReqDs.addressId = atiReqId;
038700220121  atiAdrReqDs.street = %trim(ordAdrToValDs.hsadr1);
038800220121  atiAdrReqDs.secondaryInfo = %trim(ordAdrToValDs.hsadr2);
038900220121  atiAdrReqDs.city = %trim(ordAdrToValDs.hscity);
039000220121  atiAdrReqDs.state = %trim(ordAdrToValDs.hsstte);
039100220121  atiAdrReqDs.zipCode = %trim(ordAdrToValDs.hszipc);
039200220121  atiAdrReqDs.addressee = %trim(ordAdrToValDs.hsname);
039300220121  atiAdrReqDs.urbanization = '';
039400220121  atiAdrReqDs.requestTimestamp = %timestamp();
039500220121  write atiAdrReq.rAtiAdrReq atiAdrReqDs;
039600220121end-proc;
039700220121
039800220121//--------------------------------------------------------------------------------------------------
039900220121// SetOrdSts():  Set the order status
040000220121//--------------------------------------------------------------------------------------------------
040100220121
040200220121dcl-proc SetOrdSts;
040300220121  dcl-pi SetOrdSts;
040400220121    ordNbr like(ordAdrToValDs_t.hordr#) const;
040500220121    newSts like(ordHeadDs_t.hstats) const;
040600220121  end-pi;
040700220121
040800220121  dcl-ds ordHeadDs likeds(ordHeadDs_t);
040900220121
041000220121  chain(e) (ordNbr) orHeadLa.or1headr ordHeadDs;
041100220121  if not %error() and %found(orHeadLa);
041200220121    ordHeadDs.hstats = newSts;
041300220121    update orHeadLa.or1headr ordHeadDs;
041400220121  endif;
041500220121end-proc;
041600220121
041700220121//--------------------------------------------------------------------------------------------------
041800220121// UpdateCustAdr(): Update the cutomer address
041900220121//--------------------------------------------------------------------------------------------------
042000220121
042100220121dcl-proc UpdateCustAdr;
042200220121  dcl-pi UpdateCustAdr ind;
042300220121    custNbr like(ordAdrToValDs_t.hcust#) const;
042400220121    atiAdrCanDs likeds(atiAdrCanDs_t) const;
042500220121  end-pi;
042600220121
042700220121  dcl-ds cusMasDs likeds(cusMasDs_t);
042800220121
042900220121  dcl-s updateSuccess ind inz(*on);
043000220121
043100220121  chain(n) (custNbr) ocusmas.cu1mas cusMasDs;
043200220121  if %found(ocusmas) and
043300220121     cusMasDs.caddr1 <> atiAdrCanDs.deliveryLine1 or
043400220121     cusMasDs.caddr2 <> atiAdrCanDs.deliveryLine2 or
043500220121     cusMasDs.ccity <> atiAdrCanDs.cityName or
043600220121     cusMasDs.cstate <> atiAdrCanDs.stateAbbreviation or
043700220121     cusMasDs.zip5 <> atiAdrCanDs.zipCode or
043800220121     cusMasDs.zip4 <> atiAdrCanDs.plus4Code;
043900220121    chain(e) (custNbr) ocusmas.cu1mas cusMasDs;
044000220121    if not %error() and %found(ocusmas);
044100220121      cusMasDs.caddr1 = atiAdrCanDs.deliveryLine1;
044200220121      cusMasDs.caddr2 = atiAdrCanDs.deliveryLine2;
044300220121      cusMasDs.ccity = atiAdrCanDs.cityName;
044400220121      cusMasDs.cstate = atiAdrCanDs.stateAbbreviation;
044500220121      cusMasDs.zip5 = atiAdrCanDs.zipCode;
044600220121      cusMasDs.zip4 = atiAdrCanDs.plus4Code;
044700220121      update ocusmas.cu1mas cusMasDs;
044800220121    else;
044900220121      updateSuccess = *off;
045000220121    endif;
045100220121  endif;
045200220121
045300220121  return updateSuccess;
045400220121end-proc;
045500220121
045600220121//--------------------------------------------------------------------------------------------------
045700220121// UpdateShipToAdr(): Update the ship to address
045800220121//--------------------------------------------------------------------------------------------------
045900220121
046000220121dcl-proc UpdateShipToAdr;
046100220121  dcl-pi UpdateShipToAdr ind;
046200220121    custNbr like(ordAdrToValDs_t.hcust#) const;
046300220121    adrNbr like(ordAdrToValDs_t.hsaddr) const;
046400220121    atiAdrCanDs likeds(atiAdrCanDs_t) const;
046500220121  end-pi;
046600220121
046700220121  dcl-ds shipToAdrDs likeds(shipToAdrDs_t);
046800220121
046900220121  dcl-s updateSuccess ind inz(*on);
047000220121
047100220121  chain(n) (custNbr:adrNbr) oelsh01a.sh01r1 shipToAdrDs;
047200220121  if %found(oelsh01a) and
047300220121     shipToAdrDs.shadr1 <> atiAdrCanDs.deliveryLine1 or
047400220121     shipToAdrDs.shadr2 <> atiAdrCanDs.deliveryLine2 or
047500220121     shipToAdrDs.shcity <> atiAdrCanDs.cityName or
047600220121     shipToAdrDs.shstcd <> atiAdrCanDs.stateAbbreviation or
047700220121     shipToAdrDs.shzip5 <> atiAdrCanDs.zipCode or
047800220121     shipToAdrDs.shzip4 <> atiAdrCanDs.plus4Code;
047900220121    chain(e) (custNbr:adrNbr) oelsh01a.sh01r1 shipToAdrDs;
048000220121    if not %error() and %found(oelsh01a);
048100220121      shipToAdrDs.shadr1 = atiAdrCanDs.deliveryLine1;
048200220121      shipToAdrDs.shadr2 = atiAdrCanDs.deliveryLine2;
048300220121      shipToAdrDs.shcity = atiAdrCanDs.cityName;
048400220121      shipToAdrDs.shstcd = atiAdrCanDs.stateAbbreviation;
048500220121      shipToAdrDs.shzip5 = atiAdrCanDs.zipCode;
048600220121      shipToAdrDs.shzip4 = atiAdrCanDs.plus4Code;
048700220121      update oelsh01a.sh01r1 shipToAdrDs;
048800220121    else;
048900220121      updateSuccess = *off;
049000220121    endif;
049100220121  endif;
049200220121
049300220121  return updateSuccess;
049400220121end-proc;
049500220121
049600220121//--------------------------------------------------------------------------------------------------
049700220121// UpdateOrdShipToAdr(): Update the order ship to address
049800220121//--------------------------------------------------------------------------------------------------
049900220121
050000220121dcl-proc UpdateOrdShipToAdr;
050100220121  dcl-pi UpdateOrdShipToAdr ind;
050200220121    ordNbr like(ordAdrToValDs_t.hordr#) const;
050300220121    atiAdrCanDs likeds(atiAdrCanDs_t) const;
050400220121  end-pi;
050500220121
050600220121  dcl-ds ordShipToAdrDs likeds(ordShipToAdrDs_t);
050700220121
050800220121  dcl-s updateSuccess ind inz(*on);
050900220121
051000220121  chain(n) (ordNbr) oepsh02.sh02r1 ordShipToAdrDs;
051100220121  if %found(oepsh02) and
051200220121     ordShipToAdrDs.shadr1 <> atiAdrCanDs.deliveryLine1 or
051300220121     ordShipToAdrDs.shadr2 <> atiAdrCanDs.deliveryLine2 or
051400220121     ordShipToAdrDs.shcity <> atiAdrCanDs.cityName or
051500220121     ordShipToAdrDs.shstcd <> atiAdrCanDs.stateAbbreviation or
051600220121     ordShipToAdrDs.shzip5 <> atiAdrCanDs.zipCode or
051700220121     ordShipToAdrDs.shzip4 <> atiAdrCanDs.plus4Code;
051800220121    chain(e) (ordNbr) oepsh02.sh02r1 ordShipToAdrDs;
051900220121    if not %error() and %found(oepsh02);
052000220121      ordShipToAdrDs.shadr1 = atiAdrCanDs.deliveryLine1;
052100220121      ordShipToAdrDs.shadr2 = atiAdrCanDs.deliveryLine2;
052200220121      ordShipToAdrDs.shcity = atiAdrCanDs.cityName;
052300220121      ordShipToAdrDs.shstcd = atiAdrCanDs.stateAbbreviation;
052400220121      ordShipToAdrDs.shzip5 = atiAdrCanDs.zipCode;
052500220121      ordShipToAdrDs.shzip4 = atiAdrCanDs.plus4Code;
052600220121      update oepsh02.sh02r1 ordShipToAdrDs;
052700220121    else;
052800220121      updateSuccess = *off;
052900220121    endif;
053000220121  endif;
053100220121
053200220121  return updateSuccess;
053300220121end-proc;
053400220121
053500220121//--------------------------------------------------------------------------------------------------
053600220121// UpdateOrdHdrShipToAdr(): Update the order header ship to address
053700220121//--------------------------------------------------------------------------------------------------
053800220121
053900220121dcl-proc UpdateOrdHdrShipToAdr;
054000220121  dcl-pi UpdateOrdHdrShipToAdr ind;
054100220121    ordNbr like(ordAdrToValDs_t.hordr#) const;
054200220121    atiAdrCanDs likeds(atiAdrCanDs_t) const;
054300220121  end-pi;
054400220121
054500220121  dcl-ds ordHeadDs likeds(ordHeadDs_t);
054600220121
054700220121  dcl-s updateSuccess ind inz(*on);
054800220121
054900220121  chain(n) (ordNbr) orHeadLa.or1headr ordHeadDs;
055000220121  if %found(orHeadLa) and
055100220121     ordHeadDs.hsadr1 <> atiAdrCanDs.deliveryLine1 or
055200220121     ordHeadDs.hsadr2 <> atiAdrCanDs.deliveryLine2 or
055300220121     ordHeadDs.hscity <> atiAdrCanDs.cityName or
055400220121     ordHeadDs.hsstte <> atiAdrCanDs.stateAbbreviation or
055500220121     ordHeadDs.hszipc <> atiAdrCanDs.zipCode + atiAdrCanDs.plus4Code;
055600220121    chain(e) (ordNbr) orHeadLa.or1headr ordHeadDs;
055700220121    if not %error() and %found(orHeadLa);
055800220121      ordHeadDs.hsadr1 = atiAdrCanDs.deliveryLine1;
055900220121      ordHeadDs.hsadr2 = atiAdrCanDs.deliveryLine2;
056000220121      ordHeadDs.hscity = atiAdrCanDs.cityName;
056100220121      ordHeadDs.hsstte = atiAdrCanDs.stateAbbreviation;
056200220121      ordHeadDs.hszipc = atiAdrCanDs.zipCode + atiAdrCanDs.plus4Code;
056300220121      update orHeadLa.or1headr ordHeadDs;
056400220121    else;
056500220121      updateSuccess = *off;
056600220121    endif;
056700220121  endif;
056800220121
056900220121  return updateSuccess;
057000220121end-proc;
057100220121
057200220121//--------------------------------------------------------------------------------------------------
057300220121// UpdateOrdLinShipToAdr(): Update the order line ship to address
057400220121//--------------------------------------------------------------------------------------------------
057500220121
057600220121dcl-proc UpdateOrdLinShipToAdr;
057700220121  dcl-pi UpdateOrdLinShipToAdr ind;
057800220121    ordNbr like(ordAdrToValDs_t.hordr#) const;
057900220121    atiAdrCanDs likeds(atiAdrCanDs_t) const;
058000220121  end-pi;
058100220121
058200220121  dcl-ds ordLineDs likeds(ordLineDs_t);
058300220121
058400220121  dcl-s updateNeeded  ind;
058500220121  dcl-s updateSuccess ind inz(*on);
058600220121
058700220121  setll (ordNbr) orLineLa.or1liner;
058800220121  reade(n) (ordNbr) orLineLa.or1liner ordLineDs;
058900220121  dow not %eof(orLineLa);
059000220121    if ordLineDs.lscity <> atiAdrCanDs.cityName or
059100220121       ordLineDs.lsstte <> atiAdrCanDs.stateAbbreviation or
059200220121       ordLineDs.lszip5 <> atiAdrCanDs.zipCode or
059300220121       ordLineDs.lszip4 <> atiAdrCanDs.plus4Code;
059400220121      updateNeeded = *on;
059500220121      leave;
059600220121    endif;
059700220121
059800220121    reade(n) (ordNbr) orLineLa.or1liner ordLineDs;
059900220121  enddo;
060000220121
060100220121  if updateNeeded;
060200220121    setll (ordNbr) orLineLa.or1liner;
060300220121    reade(e) (ordNbr) orLineLa.or1liner ordLineDs;
060400220121    if %error();
060500220121      updateSuccess = *off;
060600220121    else;
060700220121      dow not %eof(orLineLa);
060800220121        ordLineDs.lscity = atiAdrCanDs.cityName;
060900220121        ordLineDs.lsstte = atiAdrCanDs.stateAbbreviation;
061000220121        ordLineDs.lszip5 = atiAdrCanDs.zipCode;
061100220121        ordLineDs.lszip4 = atiAdrCanDs.plus4Code;
061200220121        update orLineLa.or1liner ordLineDs;
061300220121        reade(e) (ordNbr) orLineLa.or1liner ordLineDs;
061400220121        if %error();
061500220121          updateSuccess = *off;
061600220121          leave;
061700220121        endif;
061800220121      enddo;
061900220121    endif;
062000220121  endif;
062100220121
062200220121  return updateSuccess;
062300220121end-proc;
062400220121
062500220121//--------------------------------------------------------------------------------------------------
062600220121// WriteOrdAdrVal(): Write an order address validation record
062700220121//--------------------------------------------------------------------------------------------------
062800220121
062900220121dcl-proc WriteOrdAdrVal;
063000220121  dcl-pi WriteOrdAdrVal;
063100220121    ordNbr like(ordAdrToValDs_t.hordr#) const;
063200220121    atiReqId like(ati_uniqueId_t) const;
063300220121    errMsg like(ati_errorDs_t.message) const;
063400220121  end-pi;
063500220121
063600220121  dcl-ds ordAdrValDs likeds(ordAdrValDs_t);
063700220121
063800220121  ordAdrValDs.ordNbr = ordNbr;
063900220121  ordAdrValDs.reqId = atiReqId;
064000220121  ordAdrValDs.errMsg = errMsg;
064100220121  write ordAdrVal.ordAdrValR ordAdrValDs;
064200220121end-proc;
064300220121
