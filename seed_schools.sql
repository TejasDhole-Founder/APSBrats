-- V5__seed_schools.sql
-- Source: Official APS School Directory (AWES)
-- 135 schools extracted directly from PDF
-- city / state / cantonment derived from address column in PDF

INSERT INTO schools
    (id, name, city, state, cantonment, address, principal_name, phone, email, website, school_code, is_active)
VALUES

-- 1
(uuid_generate_v4(), 'APS Bangalore',
 'Bangalore', 'Karnataka', 'Bangalore Cantonment',
 'Abdul Hammid Barracks, K Kamraj Road, Bangalore-560042',
 'Mrs Manjula Raman', '080-25581238 / 7829055011',
 'apsblre@rediffmail.com', 'www.apsbangalore.edu.in', 'APS-BLR', TRUE),

-- 2
(uuid_generate_v4(), 'APS Bhopal',
 'Bhopal', 'Madhya Pradesh', 'Bhopal Cantonment',
 'Dronachal Neori Hills, PO Motilal Nehru Nagar, Bhopal-462038',
 'Mrs Seema Dwivedi', '0755-2800807 / 9425608289',
 'armypublicschoolbhopal@yahoo.com', 'www.apsbhopal.com', 'APS-BHO', TRUE),

-- 3
(uuid_generate_v4(), 'APS Gwalior',
 'Gwalior', 'Madhya Pradesh', 'Morar Cantonment',
 'Morar Cantt, Gwalior-474006',
 'Mrs Nilanjana Singh', '0751-2463939 / 9009463479',
 'armypublicscholgwalior@gmail.com', 'www.armyschoolgwalior.com', 'APS-GWL', TRUE),

-- 4
(uuid_generate_v4(), 'APS Jodhpur',
 'Jodhpur', 'Rajasthan', 'Jodhpur Cantonment',
 'Ajmer Road, Opp Gujar Market, Jodhpur-342010',
 'Dr (Mrs) Tabassum Khan', '0291-2510559 / 9414005442',
 'asjodhpur@sify.com', 'www.apsjodhpur.com', 'APS-JDH', TRUE),

-- 5
(uuid_generate_v4(), 'APS Pune',
 'Pune', 'Maharashtra', 'Pune Cantonment',
 'Near Empress Garden, Pune-411001',
 'Mrs Binita Poonekar', '020-26341404 / 9890896530',
 'apspune@rediffmail.com', 'www.apspune.com', 'APS-PNE', TRUE),

-- 6
(uuid_generate_v4(), 'APS Ahmedabad',
 'Ahmedabad', 'Gujarat', 'Ahmedabad Cantonment',
 'Near Hanuman Camp Shahibaug, Ahmedabad Cantt-380003',
 'Dr (Ms) Gayatri Dubey', '079-22862543 / 9408709455',
 'asacantt@yahoo.com', 'www.apsahmedabad.in', 'APS-AMD', TRUE),

-- 7
(uuid_generate_v4(), 'APS Ahmednagar',
 'Ahmednagar', 'Maharashtra', 'Ahmednagar Cantonment',
 'AC Centre and School, Ahmadnagar-414002',
 'Mr Ajith Kumar R', '0241-2323009 / 08956401934',
 'apsahmednagar01@gmail.com', 'www.apsahmednagar.com', 'APS-ANR', TRUE),

-- 8
(uuid_generate_v4(), 'APS Babina',
 'Jhansi', 'Madhya Pradesh', 'Babina Cantonment',
 'Babina Cantt-284401',
 'Mrs Dimple Shekhawat', '0510-2740437 / 08173049437',
 'armyschool3@yahoo.com', 'www.aps.babina.org', 'APS-BAB', TRUE),

-- 9
(uuid_generate_v4(), 'APS Bhuj',
 'Bhuj', 'Gujarat', 'Bhuj Military Station',
 'C/O HQ 75 (I) INF BDE GP, C/O 56 APO, PIN-908075',
 'Ms Geeta V Soni', '02832-223309 / 9427388806',
 'apsbhuj@gmail.com', 'www.apsbhuj.nic.in', 'APS-BHJ', TRUE),

-- 10
(uuid_generate_v4(), 'APS Cannanore',
 'Kannur', 'Kerala', 'Cannanore Cantonment',
 'Burnacherry PO, Cannanore-670013',
 'Mrs P Fathima Beevi', '0497-2704740 / 8281527682',
 'princiapscnr@gmail.com', 'www.apscannanore.org', 'APS-CNN', TRUE),

-- 11
(uuid_generate_v4(), 'APS Devlali',
 'Nashik', 'Maharashtra', 'Devlali Cantonment',
 'Hampdon Line, Devlali-422401',
 'Mrs Deep Kaul', '0253-2493402 / 8806083402',
 'armydev2001@yahoo.com', 'www.apsdevlali.in', 'APS-DVL', TRUE),

-- 12
(uuid_generate_v4(), 'APS Dhrangadhra',
 'Dhrangadhra', 'Gujarat', 'Dhrangadhra Military Station',
 'Dist Surendranagar, Gujarat-363310',
 'Mrs Neeti Kanungo', '02754-282024 / 9429100865',
 'armydhg2006@rediffmail.com', 'www.apsdhg.com', 'APS-DHG', TRUE),

-- 13
(uuid_generate_v4(), 'APS Golconda',
 'Hyderabad', 'Telangana', 'Golconda Military Station',
 'Army School Golconda, Hydershakote, Near Suncity, Hyderabad-500031',
 'Mrs Vidya Muralidharan', '040-20023340 / 9052823270',
 'armyschoolgolconda@gmail.com', 'www.apsgolconda.in', 'APS-GLC', TRUE),

-- 14
(uuid_generate_v4(), 'APS Jhansi',
 'Jhansi', 'Uttar Pradesh', 'Jhansi Cantonment',
 'Daulat Singh Marg, Jhansi Cantt-284001',
 'Mrs Savita Kakker', '0510-6518521 / 09454542346',
 'armyjhs@gmail.com', 'www.apsjhansi.com', 'APS-JHS', TRUE),

-- 15
(uuid_generate_v4(), 'APS Kamptee',
 'Nagpur', 'Maharashtra', 'Kamptee Cantonment',
 'The Mall Road, Kamptee Cantt-441001',
 'Vacant', '07109-270435 / 07768841379',
 'armyschool_kmt@yahoo.com', 'www.apskamptee.com', 'APS-KMT', TRUE),

-- 16
(uuid_generate_v4(), 'APS Kirkee',
 'Pune', 'Maharashtra', 'Kirkee Cantonment',
 'C/O BEG & Centre, Kirkee, Pune-411003',
 'Mrs Arti Sharma', '020-65008707 / 9405013008',
 'apskirkee11@gmail.com', 'www.apskirkee.in', 'APS-KRK', TRUE),

-- 17
(uuid_generate_v4(), 'APS Mumbai',
 'Mumbai', 'Maharashtra', 'Colaba Cantonment',
 'Dr Nanabhoy Moos Road, Opp INHS Asvini, Colaba, Mumbai-400005',
 'Mrs Vipanjot Sehdeva', '022-22182547 / 7506253330',
 'armyschoolmumbai@gmail.com', 'www.apsmumbai.com', 'APS-MUM', TRUE),

-- 18
(uuid_generate_v4(), 'APS Nasirabad',
 'Ajmer', 'Rajasthan', 'Nasirabad Cantonment',
 '19 BI Line, Nasirabad, Dist Ajmer, Rajasthan-305601',
 'Vacant', '01491-220510 / 7597289575',
 'apsnasirabad@gmail.com', 'www.apsnasirabad.com', 'APS-NSB', TRUE),

-- 19
(uuid_generate_v4(), 'APS Pangode Trivandrum',
 'Thiruvananthapuram', 'Kerala', 'Pangode Cantonment',
 'Army School, Pangode Thirumala, PO Trivandrum, Kerala-695006',
 'Mrs Sindhu Suresh', '0471-2358242 / 9446393648',
 'armyschooltvm@yahoo.co.in', 'www.armyschooltvm.nic', 'APS-TRV', TRUE),

-- 20
(uuid_generate_v4(), 'APS Saugor',
 'Sagar', 'Madhya Pradesh', 'Saugor Cantonment',
 'Koregaon, Saugor Cantt-470001',
 'Mrs Sunetra Kar', '07582-240119',
 'assaugar@rediffmail.com', 'www.apssaugor.com', 'APS-SGR', TRUE),

-- 21
(uuid_generate_v4(), 'APS Secunderabad Bolarum',
 'Secunderabad', 'Telangana', 'Bolarum Cantonment',
 'Army Public School, Bolarum, PO Jai Jawahar Nagar, Secunderabad-500087',
 'Mrs Smitha Govind', '040-27940488 / 8008954199',
 'apsbolarum@gmail.com', 'www.apsbolarum.org.in', 'APS-SCB', TRUE),

-- 22
(uuid_generate_v4(), 'APS Secunderabad RKP',
 'Secunderabad', 'Telangana', 'Secunderabad Cantonment',
 'Ramakrishnapuram, Secunderabad-500056',
 'Mrs M Usha Rani', '040-27796757 / 9701838568',
 'apsrkpuram@gmail.com', 'www.apsrkpuram.com', 'APS-SCR', TRUE),

-- 23
(uuid_generate_v4(), 'APS Wellington',
 'Nilgiris', 'Tamil Nadu', 'Wellington Cantonment',
 'DSSC, Wellington-643231, The Nilgiris',
 'Mrs Kabitha Madhu', '0423-2234538 / 9489470564',
 'armyschool@hotmail.com', 'www.armyschoolwellington.in', 'APS-WLG', TRUE),

-- 24
(uuid_generate_v4(), 'APS Dehu Road Pune',
 'Pune', 'Maharashtra', 'Dehu Road Cantonment',
 'Army School, Dehu Road, Pune-412101',
 'Mrs Paramita Nandy', '020-27670266 / 07387843988',
 'apsdehuroad@gmail.com', 'www.apsdehuroad.net', 'APS-DHR', TRUE),

-- 25
(uuid_generate_v4(), 'APS Dighi',
 'Pune', 'Maharashtra', 'Dighi Camp',
 'Army Public School, Dighi, Alandi Road, Dighi Camp, Pune-411015',
 'Mrs Shraddha Sudame', '020-65106915 / 09326129889',
 'armyschooldighi@gmail.com', 'www.apsdighi.com', 'APS-DGH', TRUE),

-- 26
(uuid_generate_v4(), 'APS Chennai',
 'Chennai', 'Tamil Nadu', 'St Thomas Mount Cantonment',
 'Army Public School, 60 Feet Road, Nadambakkam, Chennai-600089',
 'Mrs Uma Chanderasekaran', '044-22330309 / 9952026771',
 'armypublicschoolchennai@gmail.com', 'www.apschennai.com', 'APS-CHN', TRUE),

-- 27
(uuid_generate_v4(), 'APS PRTC Bangalore',
 'Bangalore', 'Karnataka', 'Bangalore Cantonment',
 'Army Public School, PRTC, Bangalore-560006',
 'Mrs Mousumi Dutta', '080-23433341 / 9448286559',
 'prs.paraschool@gmail.com', 'www.armypublicschoolprtc.com', 'APS-PRTC', TRUE),

-- 28
(uuid_generate_v4(), 'APS ASC Centre Bangalore',
 'Bangalore', 'Karnataka', 'Bangalore Cantonment',
 'Army Public School, C/O ASC Centre, Bangalore-560007',
 'Mrs Renu Rao', '080-25550677 / 9480670482',
 'apsasc@gmail.com', 'www.apsasc.edu.in', 'APS-ASC', TRUE),

-- 29
(uuid_generate_v4(), 'APS Khadakwasla',
 'Pune', 'Maharashtra', 'NDA Khadakwasla',
 'Army Public School Khadakwasla, Barrack No 3, NDA Khadakwasla, Pune-23',
 'Mrs Simple Sahay', '020-25290084 / 8975454500',
 'apskhadakwasla@gmail.com', 'www.apskhadakwasla.com', 'APS-KHD', TRUE),

-- 30
(uuid_generate_v4(), 'APS Jaisalmer',
 'Jaisalmer', 'Rajasthan', 'Jaisalmer Military Station',
 'Army Public School, Jaisalmer, C/O HQ 140 Armd Bde, C/O 56 APO, PIN-908140',
 'Mrs Roma Dullat', '02992-260077 / 9636809896',
 'apsjsm@gmail.com', NULL, 'APS-JSM', TRUE),

-- 31
(uuid_generate_v4(), 'APS Bengdubi',
 'Darjeeling', 'West Bengal', 'Bengdubi Cantonment',
 'Army Public School Bengdubi, Post Bengdubi, Dist Darjeeling, PIN-734424',
 'Mr Mushahidun Nabi', '0353-2480297 / 2480238',
 'apsbengdubi@gmail.com', 'www.apsbengdubi.net.in', 'APS-BGD', TRUE),

-- 32
(uuid_generate_v4(), 'APS Binnaguri',
 'Jalpaiguri', 'West Bengal', 'Binnaguri Cantonment',
 'PO Binnaguri Cantt, Dist Jalpaiguri, West Bengal-735232',
 'Mrs Madhumita Sengupta', '03563-259446 / 9609812324',
 'apsbinnaguri1@gmail.com', 'www.apsbinnaguri.org', 'APS-BNG', TRUE),

-- 33
(uuid_generate_v4(), 'APS Dinjan',
 'Dibrugarh', 'Assam', 'Dinjan Military Station',
 'PO Dinjan Via Panitola, Dist Dibrugarh-786189, Assam',
 'Mrs Ferdausi Sultana', '0374-2388308',
 'apsdinjan@gmail.com', 'www.apsdinjan.co.in', 'APS-DNJ', TRUE),

-- 34
(uuid_generate_v4(), 'APS Kolkata',
 'Kolkata', 'West Bengal', 'Ballygunge Military Camp',
 'Ballygunge Military Camp, Kolkata-700019',
 'Dr (Mrs) Suchitra Bhattacharya', '033-24865968 / 8697970288',
 'apskolkata94@gmail.com', 'www.apskolkata.in', 'APS-KOL', TRUE),

-- 35
(uuid_generate_v4(), 'APS Narangi',
 'Guwahati', 'Assam', 'Narangi Cantonment',
 'PO Satgaon, Guwahati-781027, Assam',
 'Mrs Prabha Dastidar', '0361-2642299 / 09435010544',
 'apsnarangi@gmail.com', 'www.armypublicschoolnarangi.org', 'APS-NRG', TRUE),

-- 36
(uuid_generate_v4(), 'APS Agartala',
 'Agartala', 'Tripura', 'Agartala Cantonment',
 'PO Kunjaban, C/O Stn HQ Agartala, Pin-799006',
 'Mrs Gunjan Gupta', '0381-2416324 / 9612911426',
 'apsagartala@gmail.com', 'www.armypublicschoolagartala.com', 'APS-AGT', TRUE),

-- 37
(uuid_generate_v4(), 'APS Bagrakote',
 'Jalpaiguri', 'West Bengal', 'Bagrakote Cantonment',
 'PO Bagrakot, Dist Jalpaiguri, West Bengal-734501',
 'Mrs Nisha Narayan', '03562-245216 / 08972817289',
 'apsbagrakote1978@gmail.com', 'www.apsbagrakote.org', 'APS-BGK', TRUE),

-- 38
(uuid_generate_v4(), 'APS Barrackpore',
 'Kolkata', 'West Bengal', 'Barrackpore Cantonment',
 'North Gate, Barrackpore Cantt, 24 PAGS (N), Kolkata-700120',
 'Mrs Moitreyee Mukherjee', '033-29532317 / 9874919911',
 'armysch.bkp@gmail.com', 'www.apsbkp.com', 'APS-BKP', TRUE),

-- 39
(uuid_generate_v4(), 'APS Basistha',
 'Guwahati', 'Assam', 'Basistha Military Station',
 'C/O 151 Base Hospital, C/O 99 APO, PIN-781029',
 'Mrs Purnima Mehra', '0361-2304739 / 03612131465',
 'as.basistha@gmail.com', 'www.apsbasistha.org', 'APS-BST', TRUE),

-- 40
(uuid_generate_v4(), 'APS Darjeeling',
 'Darjeeling', 'West Bengal', 'Darjeeling Cantonment',
 'Post Ghoom, Dist Darjeeling, West Bengal-734102',
 'Ms Dhundup Dolma', '0354-2005692 / 8348468105',
 'armyschooldarjeeling11@gmail.com', 'www.apsdarjeeling.com', 'APS-DRJ', TRUE),

-- 41
(uuid_generate_v4(), 'APS Gangtok',
 'Gangtok', 'Sikkim', 'Gangtok Cantonment',
 'Libing, New Cantt Gangtok, Sikkim-PIN-908417',
 'Mrs Iia Gan Chaughuri', '03592-270604 / 09475688140',
 'armyschoolgtk@gmail.com', 'www.apsgangtok.com', 'APS-GTK', TRUE),

-- 42
(uuid_generate_v4(), 'APS Jorhat',
 'Jorhat', 'Assam', 'Jorhat Military Station',
 'Near Rowriah MES Gate, PO Chaliha, Jorhat-785004, Assam',
 'Mrs Tasmin Hye', '0376-2333069 / 09435091277',
 'asjorhat1@gmail.com', 'www.apsjorhat.org', 'APS-JRH', TRUE),

-- 43
(uuid_generate_v4(), 'APS Kalimpong',
 'Kalimpong', 'West Bengal', 'Kalimpong Military Station',
 'Army School Durpindara, Kalimpong, HQ 27 INF DIV, PIN-908427',
 'Mrs Shova Pradhan', '03552-283647',
 'armyschoolkalimpong@gmail.com', NULL, 'APS-KLM', TRUE),

-- 44
(uuid_generate_v4(), 'APS Missamari',
 'Sonitpur', 'Assam', 'Missamari Military Station',
 'PO Missamari, Dist Sonitpur, Assam-784506',
 'Mr Shantonu Kr Borrah', '03714-253469 / 09401903667',
 'armyschool.m@gmail.com', 'www.apsmissamari.co.in', 'APS-MSM', TRUE),

-- 45
(uuid_generate_v4(), 'APS Panagarh',
 'Burdwan', 'West Bengal', 'Panagarh Military Station',
 'PO Arjunpur, Dist Burdwan, West Bengal-713402',
 'Mrs Bhavna S Dhami', '0343-6530315',
 'apspanagarh@gmail.com', 'www.armyschoolpanagarh.com', 'APS-PNG', TRUE),

-- 46
(uuid_generate_v4(), 'APS Rangapahar',
 'Dimapur', 'Nagaland', 'Rangapahar Military Station',
 'C/O HQ 3 Corps Engg Sig Regt, PIN-916803, C/O 99 APO',
 'Mr Limameren', '03862-249036',
 'armyschoolrangapahar@gmail.com', 'www.apsrangapahar.com', 'APS-RGP', TRUE),

-- 47
(uuid_generate_v4(), 'APS Shillong',
 'Shillong', 'Meghalaya', 'Shillong Cantonment',
 'HQ 101 Area, C/O 99 APO, PIN-793001',
 'Mr Rajeevan P', '0364-2560603 / 8974058286',
 'armyschoolshillong@gmail.com', 'www.asshillong.org', 'APS-SHL', TRUE),

-- 48
(uuid_generate_v4(), 'APS Sukna',
 'Darjeeling', 'West Bengal', 'Sukna Military Station',
 'C/O 1702 FPO, C/O 99 APO, PIN-734225',
 'Mr Niloy Mandal', '0353-2573419 / 94344-45478',
 'armyschoolsukna@gmail.com', 'www.apssukna.org', 'APS-SKN', TRUE),

-- 49
(uuid_generate_v4(), 'APS Tenga Valley',
 'West Kameng', 'Arunachal Pradesh', 'Tenga Military Station',
 'Army Public School Tenga Valley, Dist West Kameng, Arunachal Pradesh-790115',
 'Mr Bir Bahadur Gurung', '03782-273601 / 09191627462',
 'apstenga@gmail.com', 'www.apstenga.org', 'APS-TNG', TRUE),

-- 50
(uuid_generate_v4(), 'APS Tezpur',
 'Tezpur', 'Assam', 'Tezpur Military Station',
 'Sonitpur Dist, Assam-784001',
 'Mr Santanu Puzari', '03712-259109 / 9954365437',
 'apstezpur@gmail.com', 'www.apstezpur.org', 'APS-TZP', TRUE),

-- 51
(uuid_generate_v4(), 'APS Umroi',
 'Shillong', 'Meghalaya', 'Umroi Cantonment',
 'C/O 24 MTN BDE, C/O 99 APO, PIN-793103',
 'Vacant', '0364-2577353',
 'armyschoolumroi.33@gmail.com', 'www.apsumroicantt.com', 'APS-UMR', TRUE),

-- 52
(uuid_generate_v4(), 'APS Happy Valley Shillong',
 'Shillong', 'Meghalaya', 'Happy Valley Military Station',
 'C/O 58 GTC, Happy Valley, Shillong-930007',
 'Mrs Namita G Thakur', '0364-2585166 / 3642585166',
 'armyschoolhappyvalley58gtc@gmail.com', 'www.apshappyvalley58gtc.com', 'APS-HPV', TRUE),

-- 53
(uuid_generate_v4(), 'APS Ambala',
 'Ambala', 'Haryana', 'Ambala Cantonment',
 '90 Alexandra Road, Ambala Cantt-133001',
 'Mr Paramjit Singh', '0171-2633159 / 9416862210',
 'apsambala10@gmail.com', 'www.apsambala.com', 'APS-AMB', TRUE),

-- 54
(uuid_generate_v4(), 'APS Beas',
 'Kapurthala', 'Punjab', 'Beas Military Station',
 'Km Stone 49, GT Road (NH-1), PO Dhilwan, Dist Kapurthala, Punjab-144804',
 'Mr Subhash Joshi', '01822-273218 / 8288027171',
 'apsbeas@gmail.com', 'www.apsbeas.org', 'APS-BEA', TRUE),

-- 55
(uuid_generate_v4(), 'APS Chandimandir',
 'Panchkula', 'Haryana', 'Chandimandir Cantonment',
 'Sector D, Chandimandir-134107',
 'Mrs Suman Singh', '0172-2589605',
 'apschandimandir@gmail.com', 'www.apschandimandir.in', 'APS-CDM', TRUE),

-- 56
(uuid_generate_v4(), 'APS Dagshai',
 'Solan', 'Himachal Pradesh', 'Dagshai Cantonment',
 'Dist Solan, Himachal Pradesh-173210',
 'Mr SK Mishra', '01792-266651 / 09218026651',
 'apsdashai86@gmail.com', 'www.apsdagshai.org', 'APS-DGS', TRUE),

-- 57
(uuid_generate_v4(), 'APS Delhi Cantt',
 'New Delhi', 'Delhi', 'Delhi Cantonment',
 'Sadar Bazar Road, Delhi Cantt-110010',
 'Mrs Meera Rani Bera', '011-25694947',
 'apsdelhicantt@gmail.com', 'www.apsdc.org', 'APS-DLC', TRUE),

-- 58
(uuid_generate_v4(), 'APS Dhaula Kuan',
 'New Delhi', 'Delhi', 'Dhaula Kuan Cantonment',
 'Ridge Road, Dhaula Kuan, New Delhi-110010',
 'Mrs Mridula Pant', '011-25693040 / 25693131',
 'apsdk@rediffmail.com', 'www.apsdk.com', 'APS-DLK', TRUE),

-- 59
(uuid_generate_v4(), 'APS Jalandhar',
 'Jalandhar', 'Punjab', 'Jalandhar Cantonment',
 'Hoshiarpur Road, Jalandhar Cantt-144005',
 'Mr Ashok K Jain', '0181-2630776 / 9873766805',
 'apsjalandhar@yahoo.co.in', 'www.apsjalandhar.com', 'APS-JLD', TRUE),

-- 60
(uuid_generate_v4(), 'APS Janglot',
 'Kathua', 'Jammu & Kashmir', 'Janglot Military Station',
 'PO Janglot, Tehsil & Distt Kathua, J&K-184104',
 'Mr V Muralidharan', '01922-237237 / 01922-237238',
 'apsjanglot@gmail.com', 'www.apsjanglot.org', 'APS-JGL', TRUE),

-- 61
(uuid_generate_v4(), 'APS Mamun',
 'Pathankot', 'Punjab', 'Mamun Cantonment',
 'Via Pathankot, Tehsil & Dist Pathankot, Punjab-145002',
 'Mrs Kawaljit Kaur', '0186-2249247 / 2249248',
 'armypublicschoolmamun@gmail.com', 'www.apsmamun.org', 'APS-MMN', TRUE),

-- 62
(uuid_generate_v4(), 'APS Noida',
 'Noida', 'Uttar Pradesh', 'Noida Military Station',
 'Sector 37, Arun Vihar, Noida-201303',
 'Mrs Anita Shah', '0120-243040 / 09560457950',
 'apsnoidasec37@gmail.com', 'www.apsnoida.in', 'APS-NOI', TRUE),

-- 63
(uuid_generate_v4(), 'APS Patiala',
 'Patiala', 'Punjab', 'Patiala Cantonment',
 'Tarapore Enclave, Sangrur Road, Patiala Cantt-147001',
 'Mr Sita Ram', '0175-2200340 / 082288010227',
 'apspatiala@gmail.com', 'www.apspatiala.com', 'APS-PTL', TRUE),

-- 64
(uuid_generate_v4(), 'APS Shankar Vihar',
 'New Delhi', 'Delhi', 'Delhi Cantonment',
 'Shankar Vihar, Delhi Cantt-110010',
 'Mrs Malini Narayanan', '011-26153559 / 08447914179',
 'apssvprincipal@gmail.com', 'www.apsshankarvihar.com', 'APS-SHV', TRUE),

-- 65
(uuid_generate_v4(), 'APS Tibri Gurdaspur',
 'Gurdaspur', 'Punjab', 'Gurdaspur Military Station',
 'Army Public School Tibri, Gurdaspur Mil Stn, PIN-143534',
 'Mrs Laveena Rajput', '0184-258496 / 9988833832',
 'armyschool_tibri@yahoo.com', 'www.apstibri.com', 'APS-TBR', TRUE),

-- 66
(uuid_generate_v4(), 'APS Amritsar',
 'Amritsar', 'Punjab', 'Amritsar Cantonment',
 'Army Public School, Amritsar Cantt, Post Khasa, Dist Amritsar-143107',
 'Mrs Hem Lata Vishen', '0183-2565820 / 9501600599',
 'armyschoolasr@rediffmail.com', 'www.armyschoolasr.org.in', 'APS-ASR', TRUE),

-- 67
(uuid_generate_v4(), 'APS BD Bari',
 'Jammu', 'Jammu & Kashmir', 'BD Bari Military Station',
 'PO Industrial Area BD Bari, Tehsil Samba, Dist Jammu, J&K-181133',
 'Mrs Neeta Rawal', '01923-211299',
 'apsbdbari@gmail.com', 'www.apsbdbari.org', 'APS-BDB', TRUE),

-- 68
(uuid_generate_v4(), 'APS Birpur',
 'Dehradun', 'Uttarakhand', 'Garhi Cantonment',
 'Army Public School, Birpur, PO Garhi Cantt, Dehradun-248003',
 'Mrs Bindu Sharma', '0135-2552041 / 09761347989',
 'apsbirpur.gmail.com', 'www.apsbirpurddn.com', 'APS-BRP', TRUE),

-- 69
(uuid_generate_v4(), 'APS Damana',
 'Jammu', 'Jammu & Kashmir', 'Damana Military Station',
 'Army Public School Damana (Muthi), Jammu-181205',
 'Dr (Mrs) Renu Gupta', '0191-2604786',
 'apsdamana@gmail.com', 'www.apsdamana.org', 'APS-DMN', TRUE),

-- 70
(uuid_generate_v4(), 'APS Dehradun Clement Town',
 'Dehradun', 'Uttarakhand', 'Clement Town Cantonment',
 'Clement Town, Dehradun-248002',
 'Mrs Gitanjali Kachari', '0135-2643584 / 9927454945',
 'apsclementtown@gmail.com', 'www.apsclementtown.org', 'APS-CLT', TRUE),

-- 71
(uuid_generate_v4(), 'APS Ferozepur',
 'Ferozepur', 'Punjab', 'Ferozepur Cantonment',
 'Hospital Road, Ferozepur Cantt-152001',
 'Dr Vipin Jishtu', '01632-245437 / 9876148209',
 'apsfzr@gmail.com', 'www.apsferozepur.com', 'APS-FZR', TRUE),

-- 72
(uuid_generate_v4(), 'APS Jammu',
 'Jammu', 'Jammu & Kashmir', 'Jammu Cantonment',
 'Near Peer Baba, PO Satwari, Jammu Cantt-181205',
 'Mrs Ratna Mallick', '0191-2262992',
 'apsjc2012@gmail.com', 'www.asjammucantt.com', 'APS-JMU', TRUE),

-- 73
(uuid_generate_v4(), 'APS Kaluchak',
 'Jammu', 'Jammu & Kashmir', 'Kaluchak Military Station',
 'PO Gangyal, Jammu-180010',
 'Mr Raamesh TR', '0191-2481200',
 'apskaluchak@gmail.com', 'www.apskaluchak.com', 'APS-KLC', TRUE),

-- 74
(uuid_generate_v4(), 'APS Kandrori',
 'Gurdaspur', 'Punjab', 'Pathankot Military Station',
 'VPO Nangalbhur, Tehsil Pathankot, Dist Gurdaspur, Punjab-145101',
 'Mrs Arati Patel', '0186-2268196',
 'apsk94@gmail.com', 'www.apskandrori.com', 'APS-KND', TRUE),

-- 75
(uuid_generate_v4(), 'APS Kapurthala',
 'Kapurthala', 'Punjab', 'Kapurthala Military Station',
 'Army School, Jalandhar Road, Kapurthala-144601',
 'Mrs Madhu Dogra', '01822-221518 / 9914923184',
 'apskapurthala@gmail.com', 'www.apskpt.com', 'APS-KPT', TRUE),

-- 76
(uuid_generate_v4(), 'APS Madhopur',
 'Gurdaspur', 'Punjab', 'Pathankot Cantonment',
 'The Pathankot, Distt Gurdaspur, Punjab-145024',
 'Vacant', '01870-257380',
 'apsmadhopur@gmail.com', 'www.apsmadhopur.org.com', 'APS-MDP', TRUE),

-- 77
(uuid_generate_v4(), 'APS Miran Sahib',
 'Jammu', 'Jammu & Kashmir', 'Miran Sahib Military Station',
 'PO Miran Sahib Jammu, Tehsil R S Pura, Dist Jammu, J&K-181101',
 'Mrs Lavinder Kaur', '01923-263992',
 'apsmiransahib@gmail.com', 'www.apsmiransahib.com', 'APS-MRS', TRUE),

-- 78
(uuid_generate_v4(), 'APS Nahan',
 'Sirmour', 'Himachal Pradesh', 'Nahan Cantonment',
 'Cantt Area Nahan, Dist Sirmour, HP-173001',
 'Mr RA Prabhakar', '01702-222972 / 09857070999',
 'armypublicschoolnahan@gmail.com', 'www.apsnahan.com', 'APS-NHN', TRUE),

-- 79
(uuid_generate_v4(), 'APS Pathankot',
 'Pathankot', 'Punjab', 'Pathankot Cantonment',
 'Army Public School Pathankot, Army Area Near KV-2, Pathankot-145001',
 'Mrs Suman Rana', '0186-2227387',
 'apspathankot@gmail.com', 'www.apspathankot.org', 'APS-PTK', TRUE),

-- 80
(uuid_generate_v4(), 'APS Ratnuchak',
 'Jammu', 'Jammu & Kashmir', 'Kaluchak Military Station',
 'PO Kaluchak Via Gangyal, Dist Jammu, J&K-180010',
 'Mrs Sonal Sharma', '0191-2484553',
 'armyschoolratnuchak0@gmail.com', 'www.apsratnuchak.com', 'APS-RTC', TRUE),

-- 81
(uuid_generate_v4(), 'APS Samba',
 'Samba', 'Jammu & Kashmir', 'Samba Military Station',
 'PO & Tehsil Samba, Dist Jammu, J&K-184121',
 'Mr Arjun Singh', '01923-243102 / 217098',
 'apssamba@gmail.com', NULL, 'APS-SMB', TRUE),

-- 82
(uuid_generate_v4(), 'APS Sangrur',
 'Sangrur', 'Punjab', 'Sangrur Cantonment',
 'Army School, Sangrur Cantt, Punjab-148001',
 'Mrs Amarjit Kaur', '01672-221172',
 'apsangrur@gmail.com', 'www.apssangrur.com', 'APS-SNG', TRUE),

-- 83
(uuid_generate_v4(), 'APS Unchibassi',
 'Hoshiarpur', 'Punjab', 'Unchibassi Military Station',
 'PO Lamin, Tehsil Dasuya, Dist Hoshiarpur, Punjab-144205',
 'Vacant', '01883-322250 / 253200',
 'armyschoolub@gmail.com', 'www.armyschoolunchibassi.org', 'APS-UCB', TRUE),

-- 84
(uuid_generate_v4(), 'APS Yol Cantt',
 'Kangra', 'Himachal Pradesh', 'Yol Cantonment',
 'PO Yol Cantt, Distt Kangra, HP-176052',
 'Mr A K Ambastha', '01892-235269',
 'aaasyol@gmail.com', 'www.apsyol.org', 'APS-YOL', TRUE),

-- 85
(uuid_generate_v4(), 'APS Sunjuwan',
 'Jammu', 'Jammu & Kashmir', 'Sunjuwan Military Station',
 'Army Public School, Sunjuwan, C/O 36 Inf Bde, PIN-908036, C/O 56 APO',
 'Mr Dinesh Verma', '0191-2467879 / 0912467879',
 'apssunjuwan@gmail.com', 'www.apsunjuwan.com', 'APS-SJW', TRUE),

-- 86
(uuid_generate_v4(), 'APS Lucknow LBS',
 'Lucknow', 'Uttar Pradesh', 'Lucknow Cantonment',
 'C/O HQ Lucknow Sub Area, Chanakya Marg, Lucknow-226002',
 'Mrs Meenakshi Jayaswal', '05222483186',
 'apslbslko@gmail.com', 'www.apslbslko.ac.in', 'APS-LKL', TRUE),

-- 87
(uuid_generate_v4(), 'APS Gopalpur',
 'Berhampur', 'Odisha', 'Gopalpur Military Station',
 'C/O Army AD College, C/O 99 APO, PIN-928992',
 'Mr Pradeep Kumar', '06802343090 / 08984402770',
 'apsgopalpur@gmail.com', 'www.apsgopalpur.in', 'APS-GPL', TRUE),

-- 88
(uuid_generate_v4(), 'APS Kunraghat',
 'Gorakhpur', 'Uttar Pradesh', 'Gorakhpur Cantonment',
 'PO Kunraghat, Gorakhpur, UP-273008',
 'Mrs Deepika Arora', '05512273830 / 9454341684',
 'armypublicschoolkgt@gmail.com', 'www.apskgt.com', 'APS-KGT', TRUE),

-- 89
(uuid_generate_v4(), 'APS Lansdowne',
 'Pauri Garhwal', 'Uttarakhand', 'Lansdowne Cantonment',
 'PO Lansdowne, Dist Pauri Garhwal, UK-246155',
 'Mr James Anthony', '01386262278 / 01386262065',
 'principalaps@gmail.com', 'www.apslansdowne.com', 'APS-LDW', TRUE),

-- 90
(uuid_generate_v4(), 'APS Lucknow NR',
 'Lucknow', 'Uttar Pradesh', 'Lucknow Cantonment',
 'Nehru Road, PO Dilkusha, Lucknow-226002',
 'Mrs Neena Mathur', '05222482996',
 'apsnehruroadlucknow@gmail.com', 'www.apsnrlucknow.org', 'APS-LKN', TRUE),

-- 91
(uuid_generate_v4(), 'APS Lucknow SP',
 'Lucknow', 'Uttar Pradesh', 'Lucknow Cantonment',
 'Sardar Patel Marg, Near Topkhana Bazar, Lucknow Cantt-226002',
 'Dr (Mrs) Prerna Mitra', '0522483017',
 'apsspmarglko@gmail.com', 'www.apslucknow.com', 'APS-LKS', TRUE),

-- 92
(uuid_generate_v4(), 'APS Pithoragarh Gen BC Joshi',
 'Pithoragarh', 'Uttarakhand', 'Pithoragarh Military Station',
 'PO Bin, Dist Pithoragarh, UP-262501',
 'Mr Manish Panwar', '05964224606 / 7351006806',
 'genbcjoshiaps@gmail.com', 'www.bcjaps.net.in', 'APS-PTG', TRUE),

-- 93
(uuid_generate_v4(), 'APS Agra',
 'Agra', 'Uttar Pradesh', 'Agra Cantonment',
 'Shivaji Road, Agra Cantt-282001',
 'Mrs Rupali Gupta', '05623257516 / 2420099',
 'armyagra@gmail.com', 'www.armypublicscholagra.com', 'APS-AGR', TRUE),

-- 94
(uuid_generate_v4(), 'APS Allahabad',
 'Prayagraj', 'Uttar Pradesh', 'Allahabad Cantonment',
 'Rajiv Gandhi Marg, New Cantt, Allahabad-211001',
 'Mrs Neena Shankar', '05322420772 / 08765564583',
 'armyschoolalld@gmail.com', 'www.armyschoolalld.org', 'APS-ALD', TRUE),

-- 95
(uuid_generate_v4(), 'APS Almora',
 'Almora', 'Uttarakhand', 'Almora Cantonment',
 'Alexandra Line, Almora-263601',
 'Mr Sushil Joshi', '05962230769',
 'apsalmora@gmail.com', 'www.apsalmora.com', 'APS-ALM', TRUE),

-- 96
(uuid_generate_v4(), 'APS Bareilly Cantt',
 'Bareilly', 'Uttar Pradesh', 'Bareilly Cantonment',
 'Army School, Bareilly Cantt-243001',
 'Mr SK Saxena', '0581-2421489',
 'apsbareillycantt@gmail.com', 'www.armyschoolbareilly.com', 'APS-BRL', TRUE),

-- 97
(uuid_generate_v4(), 'APS Danapur',
 'Patna', 'Bihar', 'Danapur Cantonment',
 'Danapur Cantt-801503',
 'Mrs Dharmsheela Pandey', '06115221840 / 9431488874',
 'apsdanapur@gamil.com', 'www.apsdanapur.com', 'APS-DNP', TRUE),

-- 98
(uuid_generate_v4(), 'APS Faizabad',
 'Ayodhya', 'Uttar Pradesh', 'Faizabad Cantonment',
 '32 Punjab Line, Faizabad Cantt-224001',
 'Dr (Mr) Dheeraj Shrivastava', '05278224944 / 225180',
 'apsfaizabad@gamil.com', 'www.apsfaizabad.in', 'APS-FZB', TRUE),

-- 99
(uuid_generate_v4(), 'APS Fatehgarh',
 'Fatehgarh', 'Uttar Pradesh', 'Fatehgarh Cantonment',
 'Fatehgarh-209601',
 'Mrs Anju Raje', '05692236450 / 09235545614',
 'apsfatehgarh@gmail.com', 'www.apsfatehgarh.com', 'APS-FTG', TRUE),

-- 100
(uuid_generate_v4(), 'APS Hempur',
 'Udham Singh Nagar', 'Uttarakhand', 'Hempur Military Station',
 'HQ RTC Hempur, PO RTC Hempur, Distt Udham Singh Nagar, PIN-244716',
 'Mrs Malini Sharma', '05947223115 / 211196',
 'aps.hempur@gmail.com', 'www.apshempur.com', 'APS-HMP', TRUE),

-- 101
(uuid_generate_v4(), 'APS Jabalpur No 1',
 'Jabalpur', 'Madhya Pradesh', 'Jabalpur Cantonment',
 'GRC Jabalpur, PIN-482001',
 'Mr Manish Kumar Swami', '07612668543',
 'aps1jbp@gmail.com', 'www.armyschoolno1jbp.com', 'APS-JB1', TRUE),

-- 102
(uuid_generate_v4(), 'APS Jabalpur No 2',
 'Jabalpur', 'Madhya Pradesh', 'Jabalpur Cantonment',
 'C/O JAK RIF RC Jabalpur, PIN-482001',
 'Miss Neelu Chadha', '0761268715 / 6996555',
 'apsrjabalpur@gmail.com', 'www.aps2jabalpur.org', 'APS-JB2', TRUE),

-- 103
(uuid_generate_v4(), 'APS Meerut',
 'Meerut', 'Uttar Pradesh', 'Meerut Cantonment',
 'Meerut Cantt, Near Cantt Post Office-250001',
 'Dr (Mrs) Reeta Gupta', '01212662066 / 08191800071',
 'apsmeerut559@gamil.com', 'www.apsmeerut.com', 'APS-MRT', TRUE),

-- 104
(uuid_generate_v4(), 'APS Mhow',
 'Indore', 'Madhya Pradesh', 'Mhow Cantonment',
 'Mall Road, Mhow, MP-453441',
 'Mr PK Tiwari', '07324272747 / 9753723120',
 'apsmhow@gmail.com', 'www.apsmhow.com', 'APS-MHW', TRUE),

-- 105
(uuid_generate_v4(), 'APS Pithoragarh',
 'Pithoragarh', 'Uttarakhand', 'Pithoragarh Military Station',
 'Post Bin, Dist Pithoragarh-262501',
 'Mrs Meenu Jagdish', '05964266236',
 'armyschoolpith@gmail.com', NULL, 'APS-PIH', TRUE),

-- 106
(uuid_generate_v4(), 'APS Raiwala',
 'Dehradun', 'Uttarakhand', 'Raiwala Cantonment',
 'Raiwala Cantt, Dist Dehradun, UA-249205',
 'Mr Vijay Rajeev Wilson', '01352482023 / 08449712023',
 'apsraiwala@gmail.com', 'www.apsraiwala.com', 'APS-RWL', TRUE),

-- 107
(uuid_generate_v4(), 'APS Ramgarh',
 'Ramgarh', 'Jharkhand', 'Ramgarh Cantonment',
 'Ramgarh Cantt-829122',
 'Mrs Sandhya R Marella', '06553222107 / 226029',
 'apsramgarhcantt@gmail.com', 'www.apsramgarhcantt.com', 'APS-RMG', TRUE),

-- 108
(uuid_generate_v4(), 'APS Ranikhet',
 'Almora', 'Uttarakhand', 'Ranikhet Cantonment',
 'Near Ranikhet Club, Ranikhet-263645',
 'Mr Kamlesh Joshi', '0566221271',
 'asrkt19@gamil.com', 'www.asranikhet.com', 'APS-RNK', TRUE),

-- 109
(uuid_generate_v4(), 'APS Roorkee No 1',
 'Roorkee', 'Uttarakhand', 'Roorkee Cantonment',
 'Army Public School Roorkee No 1, Roorkee Cantt-247667',
 'Mrs Rashim Bhargava', '01332274239',
 'aps.roorkee@gamil.com', 'www.apsroorkee.com', 'APS-RK1', TRUE),

-- 110
(uuid_generate_v4(), 'APS Varanasi',
 'Varanasi', 'Uttar Pradesh', 'Varanasi Cantonment',
 'Army Public School, Varanasi Cantt-247667',
 'Mrs Rosamma Kurian', '05422502514 / 2509996',
 'apsvaranasi@gmail.com', 'www.apsvaranasi.org', 'APS-VNS', TRUE),

-- 111
(uuid_generate_v4(), 'APS Gaya',
 'Gaya', 'Bihar', 'Gaya Military Station',
 'Army Public School, Paharpur, Gaya, Bihar-823005',
 'Mrs Leena David', NULL,
 'apsgaya@gmail.com', 'www.apsgaya.com', 'APS-GYA', TRUE),

-- 112
(uuid_generate_v4(), 'APS Srinagar',
 'Srinagar', 'Jammu & Kashmir', 'Badami Bagh Cantonment',
 'BB Cantt, Srinagar, J&K-190004',
 'Mr Sandeep Kumar Marhatta', '0194-2468224 / 09419900617',
 'apssrinagar@gmail.com', 'www.apssrinagar.com', 'APS-SXR', TRUE),

-- 113
(uuid_generate_v4(), 'APS Udhampur',
 'Udhampur', 'Jammu & Kashmir', 'Udhampur Cantonment',
 'PO PTC, Udhampur, J&K-182101',
 'Vacant', '01992-274128 / 09596881756',
 'apsudhampur@gmail.com', 'www.apsudhampur.org', 'APS-UDH', TRUE),

-- 114
(uuid_generate_v4(), 'APS Akhnoor',
 'Jammu', 'Jammu & Kashmir', 'Akhnoor Military Station',
 'Army Public School Akhnoor, Usman Vihar, Near Ambaran, Akhnoor-181201',
 'Mr KC Singh Mehta', '01924-213044 / 09469180134',
 'apsakhnoor12@gmail.com', 'www.armypublicschoolarhnoor.com', 'APS-AKN', TRUE),

-- 115
(uuid_generate_v4(), 'APS Leh',
 'Leh', 'Ladakh', 'Leh Military Station',
 'C/O Ladakh Scouts Regt Centre, PIN-910368, C/O 56 APO',
 'Mrs Sheeba Sehdev', '2087 / 09596656507',
 'armyschool.asl@gmail.com', 'www.apsleh.in', 'APS-LEH', TRUE),

-- 116
(uuid_generate_v4(), 'APS Nagrota',
 'Jammu', 'Jammu & Kashmir', 'Nagrota Military Station',
 'Army Public School Nagrota, J&K-181221',
 'Mrs Maninder Kaur Kakkar', '0191-2673643 / 09419101654',
 'apsnagrota@gmail.com', 'www.apsnagrota.org', 'APS-NGT', TRUE),

-- 117
(uuid_generate_v4(), 'APS Rakhmuthi',
 'Jammu', 'Jammu & Kashmir', 'Rakhmuthi Military Station',
 'C/O HQ 191 Inf Bde, PIN-908191, C/O 56 APO',
 'Mrs Shaswati Ghosh', '01924-242863 / 01924-216431',
 'apsrakhmuthi@gmail.com', 'www.armypublicschoolrakhmuthi.org', 'APS-RKM', TRUE),

-- 118
(uuid_generate_v4(), 'APS Dhar Road Udhampur',
 'Udhampur', 'Jammu & Kashmir', 'Udhampur Military Station',
 'Army Public School Dhar Road, PO Satani, Udhampur, J&K-182126',
 'Vacant', '01992-244352 / 09622011071',
 'apsdharroad@gmail.com', 'www.apsdharroad.com', 'APS-DHD', TRUE),

-- 119
(uuid_generate_v4(), 'APS Bathinda',
 'Bathinda', 'Punjab', 'Bathinda Cantonment',
 'Bathinda Cantt, Punjab-151004',
 'Mr Parvesh Mehra', '0164-2290057',
 'apsbathindacantt@gmail.com', 'www.apsbathindacantt.org', 'APS-BTD', TRUE),

-- 120
(uuid_generate_v4(), 'APS Bikaner',
 'Bikaner', 'Rajasthan', 'Bikaner Military Station',
 'Army Public School Bikaner, Rajasthan-334001',
 'Mrs Shashi Sharma', '0151-2110224 / 09875299531',
 'apsbikaner@gmail.com', 'www.apsbikaner.org', 'APS-BKN', TRUE),

-- 121
(uuid_generate_v4(), 'APS Hisar',
 'Hisar', 'Haryana', 'Hisar Military Station',
 'Hisar Military Station, Hisar-125006',
 'Mrs Kavita Jakhar', '01662-223668 / 01662-323800',
 'apshisar@hotmail.com', 'www.apshisar.com', 'APS-HSR', TRUE),

-- 122
(uuid_generate_v4(), 'APS Itrana Alwar',
 'Alwar', 'Rajasthan', 'Itrana Cantonment',
 'Itrana Cantt, Alwar-301023',
 'Mr Vikas Sharma', '0144-2881310 / 9214911778',
 'armyschoolalwar@gmail.com', 'www.armypublicschoolalwar.in', 'APS-ALW', TRUE),

-- 123
(uuid_generate_v4(), 'APS Jaipur',
 'Jaipur', 'Rajasthan', 'Jaipur Military Station',
 'Military Station Jaipur, Jaipur-302012',
 'Mrs Manisha Tyagi', '0141-2249168 / 0141-2249051',
 'armypublicschooljaipur@gmail.com', 'www.apsjaipur.com', 'APS-JPR', TRUE),

-- 124
(uuid_generate_v4(), 'APS Ranchi',
 'Ranchi', 'Jharkhand', 'Dipatoli Cantonment',
 'Dipatoli Cantt, Via NVV Hotwar BO, Ranchi-834017',
 'Dr Abhay Kumar Singh', '0651-2273351 / 7856803294',
 'asr8208@rediffmail.com', 'www.apsranchi.com', 'APS-RNC', TRUE),

-- 125
(uuid_generate_v4(), 'APS Abohar',
 'Fazilka', 'Punjab', 'Abohar Military Station',
 'Mil Stn Abohar Cantt, PIN-152116',
 'Mr Madhup Parasar', '01634-232920',
 'apsabohar1@gmail.com', 'www.apsabohar.com', 'APS-ABH', TRUE),

-- 126
(uuid_generate_v4(), 'APS Faridkot',
 'Faridkot', 'Punjab', 'Faridkot Military Station',
 'Army Public School, Faridkot Military Station, C/O 56 APO',
 'Mrs Aarshdeep Kaur', '01639-263788 / 7696047410',
 'apsfaridkot@gmail.com', 'www.apsfaridkot.org', 'APS-FRD', TRUE),

-- 127
(uuid_generate_v4(), 'APS Fazilka',
 'Fazilka', 'Punjab', 'Fazilka Military Station',
 'Military Station Fazilka, Distt Ferozepore, Punjab-152123',
 'Mrs Baldeesh Kapula', '01638-264831 / 9914401603',
 'apsfazilka@gmail.com', 'www.apsfazilka.org', 'APS-FZK', TRUE),

-- 128
(uuid_generate_v4(), 'APS Kanpur',
 'Kanpur', 'Uttar Pradesh', 'Kanpur Cantonment',
 'Nathu Singh Road, Kanpur Cantt-208004',
 'Mrs Anshoo Tandon', '0512-2380105 / 8765187261',
 'apskcantt@gmail.com', 'www.apskanpur.com', 'APS-KNP', TRUE),

-- 129
(uuid_generate_v4(), 'APS Kota',
 'Kota', 'Rajasthan', 'Kota Military Station',
 'Army Public School, Mala Road, Kota-324001',
 'Dr (Mr) Diwakar Chaubey', '0744-2207333 / 08104875658',
 'armypublicschoolkota@gmail.com', 'www.apskota.in', 'APS-KOT', TRUE),

-- 130
(uuid_generate_v4(), 'APS Lalgarh Jattan',
 'Fazilka', 'Punjab', 'Lalgarh Jattan Military Station',
 'C/O 83 Inf Bde, PIN-908083, C/O 56 APO',
 'Vacant', '01503-288740 / 9680469899',
 'apslgj83@gmail.com', 'www.apslalgarhjattan.in', 'APS-LGJ', TRUE),

-- 131
(uuid_generate_v4(), 'APS Mathura',
 'Mathura', 'Uttar Pradesh', 'Mathura Cantonment',
 'Army Public School, Mathura Cantt-281001',
 'Mrs Deepty Chaudhary', '0565-2470120',
 'apsmathuracantt@gmail.com', 'www.apsmathuracantt.com', 'APS-MTU', TRUE),

-- 132
(uuid_generate_v4(), 'APS Sri Ganganagar',
 'Sri Ganganagar', 'Rajasthan', 'Sadhuwali Cantonment',
 'Army Public School, Sadhuwali Cantt, Sri Ganganagar, Rajasthan-335001',
 'Mrs Kulvinder Kaur Alag', '0154-2492192 / 800349835',
 'apssriganganagar@gmail.com', 'www.apssriganganagar.in', 'APS-SGN', TRUE),

-- 133
(uuid_generate_v4(), 'APS Suratgarh',
 'Sri Ganganagar', 'Rajasthan', 'Suratgarh Military Station',
 'C/O HQ 170 INF BDE, C/O 56 APO, PIN-908170',
 'Mrs Manju Chauhan', '01509-268273 / 08003545545',
 'apssuratgarh@gmail.com', 'www.armypublicschool.com', 'APS-SRG', TRUE),

-- 134
(uuid_generate_v4(), 'APS Talbehat',
 'Lalitpur', 'Uttar Pradesh', 'Talbehat Military Station',
 'Army Public School, Talbehat, C/O 373 Arty Bde, C/O 56 APO',
 NULL, NULL,
 NULL, NULL, 'APS-TLB', TRUE),

-- 135
(uuid_generate_v4(), 'APS Birchugunj Portblair',
 'Port Blair', 'Andaman & Nicobar Islands', 'Port Blair Military Station',
 'Army Public School, Birchugunj, Portblair, C/O 108 Mtn Bde, C/O 99 APO',
 NULL, NULL,
 NULL, NULL, 'APS-PBL', TRUE);
