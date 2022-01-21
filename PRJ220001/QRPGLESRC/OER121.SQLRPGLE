000100220121**free
000200220121
000300220121//--------------------------------------------------------------------------------------------------
000400220121// Program Id:     OER121
000500220121// Author:         Oscar Campbell
000600220121// Program Desc.:  Validate Order Ship to Address Error Report
000700220121// Date Created:   01/21/2022
000800220121//
000900220121// This program must be compiled with RPGPPOT(*LVL1)
001000220121// Also, LIBPOI must be in the library list.
001100220121//
001200220121//--------------------------------------------------------------------------------------------------
001300220121// 1.000 01/21/2022 JTC Original Version
001400220121//--------------------------------------------------------------------------------------------------
001500220121
001600220121ctl-opt option(*nodebugio:*srcstmt:*nounref) dftactgrp(*no) actgrp('RPC') thread(*serialize)
001700220121        bnddir('HSSF':'SQLERRORS');
001800220121
001900220121/copy libpoi/qrpglesrc,hssf_h
002000220121/copy rpcobj/qrpglesrc,hssf_h_add
002100220121/copy rpcobj/qrpglesrc,checksqlpr
002200220121
002300220121dcl-pi Oer121 extpgm('OER121');
002400220121  inReportDirectory char(12) const;
002500220121  inReportName char(10) const;
002600220121end-pi;
002700220121
002800220121// ATI Address Response by uid
002900220121dcl-f atiAdrRsp disk usage(*input) qualified keyed alias;
003000220121
003100220121// ATI Address Response Candidates by pid/uid
003200220121dcl-f atiCanDs disk usage(*input) qualified keyed alias;
003300220121
003400220121dcl-ds atiAdrRspDs likerec(atiAdrRsp.rAtiAdrRsp:*input);
003500220121dcl-ds atiAdrCanDs likerec(atiCanDs.rAtiCanDs:*input);
003600220121
003700220121dcl-ds pgmStsDs psds qualified;
003800220121  pgmName char(10) pos(1);
003900220121end-ds;
004000220121
004100220121dcl-ds rptCols qualified inz;
004200220121  ordNbr char(8);
004300220121  reqId packed(24:0);
004400220121  errMsg varchar(1024);
004500220121  street varchar(100);
004600220121  secondaryInfo varchar(32);
004700220121  city varchar(64);
004800220121  state varchar(32);
004900220121  zipCode varChar(16);
005000220121  addressee varchar(50);
005100220121end-ds;
005200220121
005300220121dcl-s book like(SSWorkBook);
005400220121dcl-s RptHdgStyle like(SSCellStyle);
005500220121dcl-s ColHdgStyle like(SSCellStyle);
005600220121dcl-s LeftText like(SSCellStyle);
005700220121dcl-s LeftTextRed like(SSCellStyle);
005800220121dcl-s Num0DecNoSep like(SSCellStyle);
005900220121dcl-s sheet like(SSSheet);
006000220121dcl-s row like(SSRow);
006100220121dcl-s rowCount int(10);
006200220121dcl-s endHdgRow int(10);
006300220121
006400220121dcl-c MAX_COL 5;
006500220121
006600220121//--------------------------------------------------------------------------------------------------
006700220121// Mainline
006800220121//--------------------------------------------------------------------------------------------------
006900220121
007000220121ss_begin_object_group(100);
007100220121book = new_XSSFWorkbook();
007200220121CreateCellStyles();
007300220121sheet = ss_newSheet(book:%trimr(pgmStsDs.pgmName));
007400220121FormatColumns();
007500220121SetHeadings();
007600220121endHdgRow = rowCount;
007700220121
007800220121OpenCursor();
007900220121dow FetchCursor();
008000220121  WriteDetailRow();
008100220121enddo;
008200220121
008300220121CloseCursor();
008400220121SetPageLayout();
008500220121ss_save(book:inReportDirectory + '/' + %trimr(inReportName) + '.xlsx');
008600220121ss_end_object_group();
008700220121
008800220121*inlr = *on ;
008900220121return;
009000220121
009100220121//--------------------------------------------------------------------------------------------------
009200220121// CreateCellStyles(): Create the different display styles used for cells in this workbook
009300220121//--------------------------------------------------------------------------------------------------
009400220121
009500220121dcl-proc CreateCellStyles;
009600220121  dcl-s font like(SSFont);
009700220121  dcl-s dataFmt like(SSDataFormat);
009800220121  dcl-s tempStr like (jString);
009900220121  dcl-s format int(5);
010000220121
010100220121  RptHdgStyle = SSWorkbook_createCellStyle(book);
010200220121  font = SSWorkbook_createFont(book);
010300220121  SSFont_setBoldweight(font:BOLDWEIGHT_BOLD);
010400220121  SSFont_setFontHeightInPoints(font:12);
010500220121  SSCellStyle_setFont(RptHdgStyle:font);
010600220121  SSCellStyle_setAlignment(RptHdgStyle:ALIGN_CENTER);
010700220121
010800220121  ColHdgStyle = SSWorkbook_createCellStyle(book);
010900220121  font = SSWorkbook_createFont(book);
011000220121  SSFont_setBoldweight(font:BOLDWEIGHT_BOLD);
011100220121  SSCellStyle_setFont(ColHdgStyle:font);
011200220121  SSCellStyle_setAlignment(ColHdgStyle:ALIGN_CENTER);
011300220121  SSCellStyle_setBorderBottom(ColHdgStyle:BORDER_THIN);
011400220121  SSCellStyle_setWrapText(ColHdgStyle:*on);
011500220121
011600220121  LeftText = SSWorkbook_createCellStyle(book);
011700220121  SSCellStyle_setAlignment(LeftText:ALIGN_LEFT);
011800220121
011900220121  LeftTextRed = SSWorkbook_createCellStyle(book);
012000220121  font = SSWorkbook_createFont(book);
012100220121  SSFont_setColor(font:COLOR_RED);
012200220121  SSCellStyle_setFont(LeftTextRed:font);
012300220121  SSCellStyle_setAlignment(LeftTextRed:ALIGN_LEFT);
012400220121
012500220121  Num0DecNoSep = SSWorkbook_createCellStyle(book);
012600220121  dataFmt = SSWorkbook_createDataFormat(book);
012700220121  tempStr = new_String('#0');
012800220121  format  = SSDataFormat_getFormat(dataFmt:tempStr);
012900220121  SSCellStyle_setDataFormat(Num0DecNoSep:format);
013000220121  SSCellStyle_setAlignment(Num0DecNoSep:ALIGN_RIGHT);
013100220121
013200220121  return;
013300220121end-proc;
013400220121
013500220121//--------------------------------------------------------------------------------------------------
013600220121// FormatColumns(): Set the column widths for the worksheet
013700220121//--------------------------------------------------------------------------------------------------
013800220121
013900220121dcl-proc FormatColumns;
014000220121
014100220121  // The column width setting is in units that are approx
014200220121  // 1/256 of a character.
014300220121  SSSheet_setColumnWidth(sheet:0:10 * 256);  // Order Number
014400220121  SSSheet_setColumnWidth(sheet:1:16 * 256);  // Request ID
014500220121  SSSheet_setColumnWidth(sheet:2:30 * 256);  // Address
014600220121  SSSheet_setColumnWidth(sheet:3:70 * 256);  // Error Message
014700220121  SSSheet_setColumnWidth(sheet:4:12 * 256);  // Candidates Returned
014800220121  SSSheet_setColumnWidth(sheet:5:30 * 256);  // Candidate Address
014900220121  return;
015000220121end-proc;
015100220121
015200220121//--------------------------------------------------------------------------------------------------
015300220121// SetHeadings(): Set the report and column headings for the worksheet
015400220121//--------------------------------------------------------------------------------------------------
015500220121
015600220121dcl-proc SetHeadings;
015700220121  dcl-s row like(SSRow);
015800220121
015900220121  rowCount = 0;
016000220121  row = SSSheet_createRow(sheet:rowCount);
016100220121  ss_merge(sheet:rowCount:0:rowCount:MAX_COL);
016200220121  ss_text(row:0:'Research Products Corporation':RptHdgStyle);
016300220121
016400220121  rowCount += 1;
016500220121  row = SSSheet_createRow(sheet:rowCount);
016600220121  ss_merge(sheet:rowCount:0:rowCount:MAX_COL);
016700220121  ss_text(row:0:'Validate Order Ship to Address Error Report':RptHdgStyle);
016800220121
016900220121  rowCount += 2;
017000220121  row = SSSheet_createRow(sheet:rowCount);
017100220121  ss_text(row:0:'Order Number':ColHdgStyle);
017200220121  ss_text(row:1:'Request ID':ColHdgStyle);
017300220121  ss_text(row:2:'Address':ColHdgStyle);
017400220121  ss_text(row:3:'Error Message':ColHdgStyle);
017500220121  ss_text(row:4:'Candidates Returned':ColHdgStyle);
017600220121  ss_text(row:5:'Candidate Address':ColHdgStyle);
017700220121
017800220121  SSSheet_createFreezePane(sheet:0:rowCount + 1);
017900220121
018000220121  return;
018100220121end-proc;
018200220121
018300220121//--------------------------------------------------------------------------------------------------
018400220121// OpenCursor(): Open a cursor to get the data for the report
018500220121//--------------------------------------------------------------------------------------------------
018600220121
018700220121dcl-proc OpenCursor;
018800220121
018900220121  exec sql declare AddressErrorCursor cursor for
019000220121    with lastadrval as
019100220121    (select ordnbr, max(reqid) as maxreqid
019200220121     from ordadrval
019300220121     group by ordnbr)
019400220121
019500220121    select adrval.ordnbr, adrval.reqid, adrval.errmsg,
019600220121           adrreq.street, adrreq.secondaryinfo, adrreq.city, adrreq.state,
019700220121           adrreq.zipcode, adrreq.addressee
019800220121    from lastadrval lastval inner join
019900220121         ordadrval adrval on lastval.maxreqid = adrval.reqid inner join
020000220121         orheadla ordhdr on adrval.ordnbr = ordhdr.hordr# inner join
020100220121         atiadrreq adrreq on adrval.reqid = adrreq.addressid
020200220121    where adrval.errmsg <> '' and ordhdr.hstats = 'A'
020300220121    order by adrval.ordnbr;
020400220121
020500220121  exec sql open AddressErrorCursor;
020600220121
020700220121  Check_SQLState();
020800220121
020900220121  return;
021000220121end-proc;
021100220121
021200220121//--------------------------------------------------------------------------------------------------
021300220121// FetchCursor():  Fetch a row from the report data cursor
021400220121//--------------------------------------------------------------------------------------------------
021500220121
021600220121dcl-proc FetchCursor;
021700220121  dcl-pi FetchCursor ind;
021800220121  end-pi;
021900220121
022000220121  dcl-s eof ind;
022100220121
022200220121  exec sql fetch next from AddressErrorCursor into :rptCols;
022300220121
022400220121  eof = Check_SQLState();
022500220121
022600220121  return not eof;
022700220121end-proc;
022800220121
022900220121//--------------------------------------------------------------------------------------------------
023000220121// CloseCursor():  Close the report data cursor
023100220121//--------------------------------------------------------------------------------------------------
023200220121
023300220121dcl-proc CloseCursor;
023400220121
023500220121  exec sql close AddressErrorCursor;
023600220121
023700220121  return;
023800220121end-proc;
023900220121
024000220121//--------------------------------------------------------------------------------------------------
024100220121// WriteDetailRow():  Write out the detail for one address validation request
024200220121//--------------------------------------------------------------------------------------------------
024300220121
024400220121dcl-proc WriteDetailRow;
024500220121  dcl-s candidatesReturned like(atiAdrRspDs.candidatesReturned);
024600220121
024700220121  rowCount += 1;
024800220121  row = SSSheet_createRow(sheet:rowCount);
024900220121
025000220121  ss_text(row:0:rptCols.ordNbr:LeftText);
025100220121  ss_num(row:1:rptCols.reqId:Num0DecNoSep);
025200220121  ss_text(row:2:rptCols.addressee:LeftText);
025300220121  ss_text(row:3:rptCols.errMsg:LeftTextRed);
025400220121
025500220121  chain rptCols.reqId atiAdrRsp.rAtiAdrRsp atiAdrRspDs;
025600220121  if %found(atiAdrRsp);
025700220121    candidatesReturned = atiAdrRspDs.candidatesReturned;
025800220121  endif;
025900220121
026000220121  ss_num(row:4:candidatesReturned:Num0DecNoSep);
026100220121
026200220121  if candidatesReturned > 0;
026300220121   setll (rptCols.reqId) atiCanDs.rAtiCanDs;
026400220121   reade (rptCols.reqId) atiCanDs.rAtiCanDs atiAdrCanDs;
026500220121   if not %eof(atiCanDs);
026600220121     ss_text(row:5:atiAdrCanDs.addressee:LeftText);
026700220121   endif;
026800220121  endif;
026900220121
027000220121  rowCount += 1;
027100220121  row = SSSheet_createRow(sheet:rowCount);
027200220121  ss_text(row:2:rptCols.street:LeftText);
027300220121
027400220121  if candidatesReturned > 0;
027500220121    ss_text(row:5:atiAdrCanDs.deliveryLine1:LeftText);
027600220121  endif;
027700220121
027800220121  if rptCols.secondaryInfo <> '' or
027900220121     candidatesReturned > 0 and atiAdrCanDs.deliveryLine2 <> '';
028000220121    rowCount += 1;
028100220121    row = SSSheet_createRow(sheet:rowCount);
028200220121    ss_text(row:2:rptCols.secondaryInfo:LeftText);
028300220121
028400220121    if candidatesReturned > 0 and atiAdrCanDs.deliveryLine2 <> '';
028500220121      ss_text(row:5:atiAdrCanDs.deliveryLine2:LeftText);
028600220121    endif;
028700220121  endif;
028800220121
028900220121  rowCount += 1;
029000220121  row = SSSheet_createRow(sheet:rowCount);
029100220121
029200220121  if %len(rptCols.zipCode) = 9;
029300220121    ss_text(row:2:rptCols.city + ' ' + rptCols.state + ' ' +
029400220121            %subst(rptCols.zipCode:1:5) + '-' + %subst(rptCols.zipCode:6:4):LeftText);
029500220121  else;
029600220121    ss_text(row:2:rptCols.city + ' ' + rptCols.state + ' ' + rptCols.zipCode:LeftText);
029700220121  endif;
029800220121
029900220121  if candidatesReturned > 0;
030000220121    ss_text(row:5:atiAdrCanDs.lastLine:LeftText);
030100220121  endif;
030200220121
030300220121  if candidatesReturned > 1;
030400220121    reade (rptCols.reqId) atiCanDs.rAtiCanDs atiAdrCanDs;
030500220121    dow not %eof(atiCanDs);
030600220121      rowCount += 1;
030700220121      row = SSSheet_createRow(sheet:rowCount);
030800220121      ss_text(row:5:atiAdrCanDs.addressee:LeftText);
030900220121      rowCount += 1;
031000220121      row = SSSheet_createRow(sheet:rowCount);
031100220121      ss_text(row:5:atiAdrCanDs.deliveryLine1:LeftText);
031200220121
031300220121      if atiAdrCanDs.deliveryLine2 <> '';
031400220121        rowCount += 1;
031500220121        row = SSSheet_createRow(sheet:rowCount);
031600220121        ss_text(row:5:atiAdrCanDs.deliveryLine2:LeftText);
031700220121      endif;
031800220121
031900220121      rowCount += 1;
032000220121      row = SSSheet_createRow(sheet:rowCount);
032100220121      ss_text(row:5:atiAdrCanDs.lastLine:LeftText);
032200220121      reade (rptCols.reqId) atiCanDs.rAtiCanDs atiAdrCanDs;
032300220121    enddo;
032400220121  endif;
032500220121
032600220121  rowCount += 1;
032700220121
032800220121  return;
032900220121end-proc;
033000220121
033100220121//--------------------------------------------------------------------------------------------------
033200220121// SetPageLayout():  Set the page layout
033300220121//--------------------------------------------------------------------------------------------------
033400220121
033500220121dcl-proc SetPageLayout;
033600220121  dcl-s printSetup like(SSPrintSetup);
033700220121
033800220121  printSetup = SSSheet_getPrintSetup(sheet);
033900220121  SSPrintSetup_setLandscape(printSetup:*on);
034000220121  SSPrintSetup_setScale(printSetup:70);
034100220121  SSPrintSetup_setPaperSize(printSetup:PAPER_SIZE_LETTER);
034200220121  SS_header_setLeft(sheet:SS_header_date() + ' ' + SS_header_time());
034300220121  SS_header_setCenter(sheet:SS_header_font('Arial':'Normal') + SS_header_fontSize(12) +
034400220121    'Validate Order Ship to Address Error Report');
034500220121  SS_header_setRight(sheet:SS_header_sheetName());
034600220121  SS_footer_setCenter(sheet:'Page ' + SS_footer_page() + ' of ' + SS_footer_numPages());
034700220121  SSSheet_setPrintGridLines(sheet:*on);
034800220121  SSSheet_setHorizontallyCenter(sheet:*on);
034900220121  SS_setRepeating(book:sheet:-1:-1:0:endHdgRow);
035000220121
035100220121  return;
035200220121end-proc;
035300220121
