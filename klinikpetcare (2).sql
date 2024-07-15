-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Generation Time: Jul 15, 2024 at 06:27 AM
-- Server version: 10.4.32-MariaDB
-- PHP Version: 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `klinikpetcare`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `CountDoctors` ()   BEGIN
    DECLARE total_doctors INT;
    SELECT COUNT(*) INTO total_doctors FROM Dokter_Hewan;
    IF total_doctors > 0 THEN
        SELECT CONCAT('Jumlah total dokter hewan: ', total_doctors) AS Result;
    ELSE
        SELECT 'Belum ada data dokter hewan yang tersedia' AS Result;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `GetLaporanPemeriksaanByOwnerAndPetIDs` (`owner_id` INT, `pet_id` INT)   BEGIN
    IF EXISTS (SELECT 1 FROM Pemilik WHERE id_pemilik = owner_id) THEN
        IF EXISTS (SELECT 1 FROM Hewan WHERE id_hewan = pet_id AND id_pemilik = owner_id) THEN
            SELECT LP.id_laporan, LP.tanggal_pemeriksaan, LP.keluhan
            FROM Laporan_Pemeriksaan LP
            JOIN Hewan H ON LP.id_hewan = H.id_hewan
            WHERE H.id_hewan = pet_id;
        ELSE
            SELECT 'Hewan tidak ditemukan untuk pemilik' AS message;
        END IF;
    ELSE
        SELECT 'Pemilik tidak ditemukan' AS message;
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `MasukkanLaporanBaru` (IN `id_hewan` INT, IN `id_dokter` INT, IN `tanggal` DATE, IN `keluhan` TEXT, IN `status_laporan` ENUM('belum','sudah'))   BEGIN
    DECLARE hewan_ada INT DEFAULT 0;
    DECLARE dokter_ada INT DEFAULT 0;

    SELECT COUNT(*) INTO hewan_ada
    FROM Hewan
    WHERE id_hewan = id_hewan;
    SELECT COUNT(*) INTO dokter_ada
    FROM Dokter_Hewan
    WHERE id_dokter_hewan = id_dokter;
    
    IF hewan_ada > 0 THEN
        IF dokter_ada > 0 THEN
            INSERT INTO Laporan_Pemeriksaan (id_hewan, id_dokter_hewan, tanggal_pemeriksaan, keluhan, status)
            VALUES (id_hewan, id_dokter, tanggal, keluhan, status_laporan);
        ELSE
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Dokter tidak ditemukan';
        END IF;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Hewan tidak ditemukan';
    END IF;
END$$

--
-- Functions
--
CREATE DEFINER=`root`@`localhost` FUNCTION `CountReportsByOwnerAndDateRange` (`owner_id` INT, `start_date` DATE, `end_date` DATE) RETURNS INT(11)  BEGIN
    DECLARE report_count INT;
    SELECT COUNT(*)
    INTO report_count
    FROM Laporan_Pemeriksaan lp
    JOIN Hewan h ON lp.id_hewan = h.id_hewan
    WHERE h.id_pemilik = owner_id
    AND lp.tanggal_pemeriksaan BETWEEN start_date AND end_date;
    RETURN report_count;
END$$

CREATE DEFINER=`root`@`localhost` FUNCTION `TotalHewan` () RETURNS INT(11)  BEGIN
    DECLARE total INT;
    SELECT COUNT(*) INTO total FROM Hewan;
    RETURN total;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `dokter_hewan`
--

CREATE TABLE `dokter_hewan` (
  `id_dokter_hewan` int(11) NOT NULL,
  `nama` varchar(100) DEFAULT NULL,
  `spesialisasi` varchar(100) DEFAULT NULL,
  `nomor_telepon` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `dokter_hewan`
--

INSERT INTO `dokter_hewan` (`id_dokter_hewan`, `nama`, `spesialisasi`, `nomor_telepon`) VALUES
(1, 'Dr. Surya', 'Mata', '0812345678'),
(2, 'Dr. Dharma', 'Bedah', '0856789123'),
(3, 'Dr. Wisnu', 'Gigi', '0876543210'),
(4, 'Dr. Rahayu', 'Kardiologi', '0811112222'),
(5, 'Dr. Dewi', 'Mata', '0888889999'),
(6, 'Dr. Adi', 'Umum', '0812345678'),
(7, 'Dr. Budi', 'Umum', '0856789123'),
(8, 'Dr. Agus', 'Dalam', '0876543210');

--
-- Triggers `dokter_hewan`
--
DELIMITER $$
CREATE TRIGGER `after_delete_dokter_hewan` AFTER DELETE ON `dokter_hewan` FOR EACH ROW BEGIN
    INSERT INTO log_dokter_hewan (action, dokter_id, nama, action_time) 
    VALUES ('DELETE', OLD.id_dokter_hewan, OLD.nama, NOW());
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `after_insert_dokter_hewan` AFTER INSERT ON `dokter_hewan` FOR EACH ROW BEGIN
    INSERT INTO log_dokter_hewan (action, dokter_id, nama, action_time) 
    VALUES ('INSERT', NEW.id_dokter_hewan, NEW.nama, NOW());
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `after_update_dokter_hewan` AFTER UPDATE ON `dokter_hewan` FOR EACH ROW BEGIN
    INSERT INTO log_dokter_hewan (action, dokter_id, nama, nama_baru, action_time) 
    VALUES ('UPDATE', NEW.id_dokter_hewan, OLD.nama, NEW.nama, NOW());
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `before_delete_dokter_hewan` BEFORE DELETE ON `dokter_hewan` FOR EACH ROW BEGIN
    IF EXISTS (SELECT 1 FROM laporan_pemeriksaan WHERE id_dokter_hewan = OLD.id_dokter_hewan AND status = 'Belum') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'hewan belum sembuh';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `before_insert_dokter_hewan` BEFORE INSERT ON `dokter_hewan` FOR EACH ROW BEGIN
    -- Memastikan nomor telepon tidak duplikat
    IF EXISTS (SELECT 1 FROM dokter_hewan WHERE nomor_telepon = NEW.nomor_telepon) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Nomor telepon sudah digunakan';
    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `before_update_dokter_hewan` BEFORE UPDATE ON `dokter_hewan` FOR EACH ROW BEGIN
    IF NEW.spesialisasi NOT IN ('Umum', 'Bedah', 'Gigi', 'Kardiologi', 'Mata', 'Dalam') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Spesialisasi tidak valid';
    END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Stand-in structure for view `dokter_umum`
-- (See below for the actual view)
--
CREATE TABLE `dokter_umum` (
`id_dokter_hewan` int(11)
,`nama` varchar(100)
,`spesialisasi` varchar(100)
,`nomor_telepon` varchar(20)
);

-- --------------------------------------------------------

--
-- Table structure for table `hewan`
--

CREATE TABLE `hewan` (
  `id_hewan` int(11) NOT NULL,
  `nama` varchar(100) DEFAULT NULL,
  `jenis` varchar(100) DEFAULT NULL,
  `id_pemilik` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `hewan`
--

INSERT INTO `hewan` (`id_hewan`, `nama`, `jenis`, `id_pemilik`) VALUES
(1, 'Miko', 'Kucing', 1),
(2, 'Rocky', 'Anjing', 1),
(3, 'Luna', 'Kucing', 2),
(4, 'Bella', 'Anjing', 2),
(5, 'Coco', 'Kucing', 2),
(6, 'Fluffy', 'Kucing', 3),
(7, 'Snowy', 'Anjing', 4),
(8, 'Milo', 'Anjing', 4),
(9, 'Lucky', 'Anjing', 4),
(10, 'Putih', 'Kucing', 5);

-- --------------------------------------------------------

--
-- Table structure for table `idx_spesialisasi_tanggal_pemeriksaan`
--

CREATE TABLE `idx_spesialisasi_tanggal_pemeriksaan` (
  `id` int(11) NOT NULL,
  `id_laporan` int(11) DEFAULT NULL,
  `id_obat` int(11) DEFAULT NULL,
  `tanggal` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Stand-in structure for view `laporan_demam`
-- (See below for the actual view)
--
CREATE TABLE `laporan_demam` (
`id_laporan` int(11)
,`id_hewan` int(11)
,`id_dokter_hewan` int(11)
,`tanggal_pemeriksaan` date
,`keluhan` text
);

-- --------------------------------------------------------

--
-- Stand-in structure for view `laporan_demam_terbaru`
-- (See below for the actual view)
--
CREATE TABLE `laporan_demam_terbaru` (
`id_laporan` int(11)
,`id_hewan` int(11)
,`id_dokter_hewan` int(11)
,`tanggal_pemeriksaan` date
,`keluhan` text
);

-- --------------------------------------------------------

--
-- Table structure for table `laporan_pemeriksaan`
--

CREATE TABLE `laporan_pemeriksaan` (
  `id_laporan` int(11) NOT NULL,
  `id_hewan` int(11) DEFAULT NULL,
  `id_dokter_hewan` int(11) DEFAULT NULL,
  `tanggal_pemeriksaan` date DEFAULT NULL,
  `keluhan` text DEFAULT NULL,
  `status` varchar(10) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `laporan_pemeriksaan`
--

INSERT INTO `laporan_pemeriksaan` (`id_laporan`, `id_hewan`, `id_dokter_hewan`, `tanggal_pemeriksaan`, `keluhan`, `status`) VALUES
(1, 1, 6, '2024-07-08', 'Demam', 'sudah'),
(2, 3, 1, '2024-07-08', 'Muntah', 'belum'),
(3, 5, 7, '2024-07-08', 'Cacingan', 'sudah'),
(4, 4, 2, '2024-07-09', 'Luka pada kaki', 'belum'),
(5, 9, 1, '2024-07-09', 'Batuk', 'sudah'),
(6, 6, 7, '2024-07-09', 'Demam tinggi', 'sudah'),
(7, 7, 5, '2024-07-09', 'Mata merah', 'belum'),
(8, 1, 6, '2024-07-10', 'Cacingan', 'belum'),
(9, 5, 5, '2024-07-10', 'Mata bengkak', 'sudah'),
(10, 8, 1, '2024-07-11', 'Rontok bulu', 'belum'),
(11, 8, 3, '2024-07-12', 'Gusi Berdarah', 'belum'),
(12, 2, 2, '2024-07-12', 'Patah Tulang kaki', 'belum'),
(13, 7, 5, '2024-07-12', 'Mata Belekan', 'belum'),
(14, 1, 6, '2024-07-12', 'Muntah Bulu', 'belum'),
(15, 10, 7, '2024-07-13', 'Sakit perut', 'sudah'),
(16, 4, 7, '2024-07-13', 'Sakit perut', 'belum'),
(17, 7, 1, '2024-07-14', 'Pilek', 'belum'),
(18, 8, 3, '2024-07-14', 'Gigi Patah', 'belum'),
(19, 3, 4, '2024-07-14', 'Obesitas', 'belum'),
(20, 3, 6, '2024-07-15', 'Diare', 'sudah'),
(21, 1, 6, '2024-07-15', 'Bulu Rontok ', 'belum'),
(22, 2, 8, '2024-07-15', 'Patah Ekor', 'belum'),
(23, 5, 7, '2024-07-16', 'Pembengkakan Mata', 'sudah'),
(24, 4, 8, '2024-07-18', 'Sakit Hati', 'belum'),
(25, 5, 1, '2024-07-19', 'Sakit perut', 'sudah'),
(51, 2, 3, '2024-07-11', 'Demam Ringan', 'belum'),
(52, 4, 5, '2024-07-20', 'Pilek', 'belum');

-- --------------------------------------------------------

--
-- Stand-in structure for view `laporan_sederhana`
-- (See below for the actual view)
--
CREATE TABLE `laporan_sederhana` (
`id_laporan` int(11)
,`id_hewan` int(11)
,`tanggal_pemeriksaan` date
);

-- --------------------------------------------------------

--
-- Table structure for table `log_dokter_hewan`
--

CREATE TABLE `log_dokter_hewan` (
  `id_log_dokter` int(11) NOT NULL,
  `action` varchar(10) DEFAULT NULL,
  `dokter_id` int(11) DEFAULT NULL,
  `nama` varchar(50) NOT NULL,
  `nama_baru` varchar(255) NOT NULL,
  `action_time` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `log_dokter_hewan`
--

INSERT INTO `log_dokter_hewan` (`id_log_dokter`, `action`, `dokter_id`, `nama`, `nama_baru`, `action_time`) VALUES
(1, 'INSERT', 13, 'Haidar', '', '2024-07-14 20:58:26'),
(2, 'UPDATE', 1, 'Dr. Surya', 'Dr. Surya', '2024-07-14 21:03:43'),
(3, 'DELETE', 13, 'Haidar', '', '2024-07-14 21:06:52');

-- --------------------------------------------------------

--
-- Table structure for table `obat`
--

CREATE TABLE `obat` (
  `id_obat` int(11) NOT NULL,
  `nama` varchar(100) DEFAULT NULL,
  `deskripsi` text DEFAULT NULL,
  `harga` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `obat`
--

INSERT INTO `obat` (`id_obat`, `nama`, `deskripsi`, `harga`) VALUES
(1, 'Obat Perut', 'Obat untuk masalah pencernaan', 25.00),
(2, 'Vitamin A', 'Suplemen untuk kesehatan mata', 15.50),
(3, 'Antibiotik', 'Obat untuk infeksi', 30.00),
(4, 'Obat Demam', 'Obat untuk meredakan demam', 18.75),
(5, 'Penguat Tulang', 'Suplemen untuk tulang dan gigi', 22.00),
(6, 'Pil Tidur', 'Obat untuk bantuan tidur', 10.25),
(7, 'Cacingan Dewasa', 'Obat untuk cacing dewasa', 27.80),
(8, 'Obat Pencernaan', 'Obat untuk masalah pencernaan', 20.50),
(9, 'Salep Luka', 'Salep untuk mempercepat penyembuhan luka', 35.00),
(10, 'Obat Penghilang Rasa Sakit', 'Obat untuk menghilangkan rasa sakit', 40.00),
(11, 'Obat Batuk', 'Obat untuk meredakan batuk', 16.50),
(12, 'Vitamin C', 'Suplemen untuk meningkatkan sistem kekebalan tubuh', 12.75);

-- --------------------------------------------------------

--
-- Table structure for table `pemilik`
--

CREATE TABLE `pemilik` (
  `id_pemilik` int(11) NOT NULL,
  `nama` varchar(100) DEFAULT NULL,
  `alamat` varchar(255) DEFAULT NULL,
  `nomor_telepon` varchar(20) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `pemilik`
--

INSERT INTO `pemilik` (`id_pemilik`, `nama`, `alamat`, `nomor_telepon`) VALUES
(1, 'Budi Santoso', 'Jl. Pemilik 1', '0812345678'),
(2, 'Ani Sutarti', 'Jl. Pemilik 2', '0856789123'),
(3, 'Dewi Pratiwi', 'Jl. Pemilik 3', '0876543210'),
(4, 'Agus Wijaya', 'Jl. Pemilik 4', '0811112222'),
(5, 'Siti Rahayu', 'Jl. Pemilik 5', '0888889999');

-- --------------------------------------------------------

--
-- Table structure for table `resep`
--

CREATE TABLE `resep` (
  `id_resep` int(11) NOT NULL,
  `id_laporan` int(11) DEFAULT NULL,
  `id_obat` int(11) DEFAULT NULL,
  `tanggal_resep` date DEFAULT NULL,
  `keterangan` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `resep`
--

INSERT INTO `resep` (`id_resep`, `id_laporan`, `id_obat`, `tanggal_resep`, `keterangan`) VALUES
(293, 1, 4, '2024-07-08', 'Obat demam'),
(294, 2, 3, '2024-07-08', 'Obat anti-muntah'),
(295, 3, 7, '2024-07-08', 'Obat cacing dewasa'),
(296, 4, 9, '2024-07-09', 'Salep luka'),
(297, 5, 11, '2024-07-09', 'Obat batuk'),
(298, 6, 4, '2024-07-10', 'Obat demam tinggi'),
(299, 7, 10, '2024-07-10', 'Obat mata merah'),
(300, 8, 12, '2024-07-11', 'Obat rontok bulu'),
(301, 9, 12, '2024-07-12', 'Obat gusi berdarah'),
(302, 10, 11, '2024-07-12', 'Obat mata belekan'),
(303, 11, 4, '2024-07-13', 'Obat pilek'),
(304, 12, 1, '2024-07-13', 'Obat sakit perut'),
(305, 13, 6, '2024-07-14', 'Obat gigi patah'),
(306, 14, 5, '2024-07-14', 'Obat obesitas'),
(307, 15, 3, '2024-07-15', 'Obat diare'),
(308, 16, 4, '2024-07-15', 'Obat bulu rontok'),
(309, 17, 7, '2024-07-16', 'Obat pembengkakan mata'),
(310, 18, 10, '2024-07-18', 'Obat sakit hati'),
(311, 19, 1, '2024-07-19', 'Obat sakit perut'),
(312, 20, 2, '2024-07-19', 'Obat patah ekor'),
(313, 21, 4, '2024-07-20', 'Obat demam'),
(314, 22, 2, '2024-07-20', 'Vitamin A'),
(315, 23, 3, '2024-07-21', 'Obat anti-muntah'),
(316, 24, 5, '2024-07-21', 'Penguat tulang'),
(317, 25, 7, '2024-07-22', 'Obat cacing dewasa');

-- --------------------------------------------------------

--
-- Structure for view `dokter_umum`
--
DROP TABLE IF EXISTS `dokter_umum`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `dokter_umum`  AS SELECT `dokter_hewan`.`id_dokter_hewan` AS `id_dokter_hewan`, `dokter_hewan`.`nama` AS `nama`, `dokter_hewan`.`spesialisasi` AS `spesialisasi`, `dokter_hewan`.`nomor_telepon` AS `nomor_telepon` FROM `dokter_hewan` WHERE `dokter_hewan`.`spesialisasi` = 'Umum' ;

-- --------------------------------------------------------

--
-- Structure for view `laporan_demam`
--
DROP TABLE IF EXISTS `laporan_demam`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `laporan_demam`  AS SELECT `laporan_pemeriksaan`.`id_laporan` AS `id_laporan`, `laporan_pemeriksaan`.`id_hewan` AS `id_hewan`, `laporan_pemeriksaan`.`id_dokter_hewan` AS `id_dokter_hewan`, `laporan_pemeriksaan`.`tanggal_pemeriksaan` AS `tanggal_pemeriksaan`, `laporan_pemeriksaan`.`keluhan` AS `keluhan` FROM `laporan_pemeriksaan` WHERE `laporan_pemeriksaan`.`keluhan` like '%Demam%'WITH CASCADED CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Structure for view `laporan_demam_terbaru`
--
DROP TABLE IF EXISTS `laporan_demam_terbaru`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `laporan_demam_terbaru`  AS SELECT `laporan_demam`.`id_laporan` AS `id_laporan`, `laporan_demam`.`id_hewan` AS `id_hewan`, `laporan_demam`.`id_dokter_hewan` AS `id_dokter_hewan`, `laporan_demam`.`tanggal_pemeriksaan` AS `tanggal_pemeriksaan`, `laporan_demam`.`keluhan` AS `keluhan` FROM `laporan_demam` WHERE `laporan_demam`.`tanggal_pemeriksaan` > '2024-07-10'WITH CASCADED CHECK OPTION  ;

-- --------------------------------------------------------

--
-- Structure for view `laporan_sederhana`
--
DROP TABLE IF EXISTS `laporan_sederhana`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `laporan_sederhana`  AS SELECT `laporan_pemeriksaan`.`id_laporan` AS `id_laporan`, `laporan_pemeriksaan`.`id_hewan` AS `id_hewan`, `laporan_pemeriksaan`.`tanggal_pemeriksaan` AS `tanggal_pemeriksaan` FROM `laporan_pemeriksaan` ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `dokter_hewan`
--
ALTER TABLE `dokter_hewan`
  ADD PRIMARY KEY (`id_dokter_hewan`);

--
-- Indexes for table `hewan`
--
ALTER TABLE `hewan`
  ADD PRIMARY KEY (`id_hewan`),
  ADD KEY `id_pemilik` (`id_pemilik`);

--
-- Indexes for table `idx_spesialisasi_tanggal_pemeriksaan`
--
ALTER TABLE `idx_spesialisasi_tanggal_pemeriksaan`
  ADD PRIMARY KEY (`id`),
  ADD KEY `id_obat` (`id_obat`),
  ADD KEY `idx_laporan_obat` (`id_laporan`,`id_obat`),
  ADD KEY `idx_laporan_obat1` (`id_laporan`,`id_obat`);

--
-- Indexes for table `laporan_pemeriksaan`
--
ALTER TABLE `laporan_pemeriksaan`
  ADD PRIMARY KEY (`id_laporan`),
  ADD KEY `id_dokter_hewan` (`id_dokter_hewan`),
  ADD KEY `idx_hewan_tanggal` (`id_hewan`,`tanggal_pemeriksaan`);

--
-- Indexes for table `log_dokter_hewan`
--
ALTER TABLE `log_dokter_hewan`
  ADD PRIMARY KEY (`id_log_dokter`);

--
-- Indexes for table `obat`
--
ALTER TABLE `obat`
  ADD PRIMARY KEY (`id_obat`);

--
-- Indexes for table `pemilik`
--
ALTER TABLE `pemilik`
  ADD PRIMARY KEY (`id_pemilik`);

--
-- Indexes for table `resep`
--
ALTER TABLE `resep`
  ADD PRIMARY KEY (`id_resep`),
  ADD KEY `id_obat` (`id_obat`),
  ADD KEY `idx_laporan_tanggal` (`id_laporan`,`tanggal_resep`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `dokter_hewan`
--
ALTER TABLE `dokter_hewan`
  MODIFY `id_dokter_hewan` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT for table `hewan`
--
ALTER TABLE `hewan`
  MODIFY `id_hewan` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `idx_spesialisasi_tanggal_pemeriksaan`
--
ALTER TABLE `idx_spesialisasi_tanggal_pemeriksaan`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `laporan_pemeriksaan`
--
ALTER TABLE `laporan_pemeriksaan`
  MODIFY `id_laporan` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=54;

--
-- AUTO_INCREMENT for table `log_dokter_hewan`
--
ALTER TABLE `log_dokter_hewan`
  MODIFY `id_log_dokter` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `obat`
--
ALTER TABLE `obat`
  MODIFY `id_obat` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT for table `pemilik`
--
ALTER TABLE `pemilik`
  MODIFY `id_pemilik` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `resep`
--
ALTER TABLE `resep`
  MODIFY `id_resep` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=318;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `hewan`
--
ALTER TABLE `hewan`
  ADD CONSTRAINT `hewan_ibfk_1` FOREIGN KEY (`id_pemilik`) REFERENCES `pemilik` (`id_pemilik`);

--
-- Constraints for table `idx_spesialisasi_tanggal_pemeriksaan`
--
ALTER TABLE `idx_spesialisasi_tanggal_pemeriksaan`
  ADD CONSTRAINT `idx_spesialisasi_tanggal_pemeriksaan_ibfk_1` FOREIGN KEY (`id_laporan`) REFERENCES `laporan_pemeriksaan` (`id_laporan`),
  ADD CONSTRAINT `idx_spesialisasi_tanggal_pemeriksaan_ibfk_2` FOREIGN KEY (`id_obat`) REFERENCES `obat` (`id_obat`);

--
-- Constraints for table `laporan_pemeriksaan`
--
ALTER TABLE `laporan_pemeriksaan`
  ADD CONSTRAINT `laporan_pemeriksaan_ibfk_1` FOREIGN KEY (`id_hewan`) REFERENCES `hewan` (`id_hewan`),
  ADD CONSTRAINT `laporan_pemeriksaan_ibfk_2` FOREIGN KEY (`id_dokter_hewan`) REFERENCES `dokter_hewan` (`id_dokter_hewan`);

--
-- Constraints for table `resep`
--
ALTER TABLE `resep`
  ADD CONSTRAINT `resep_ibfk_1` FOREIGN KEY (`id_laporan`) REFERENCES `laporan_pemeriksaan` (`id_laporan`),
  ADD CONSTRAINT `resep_ibfk_2` FOREIGN KEY (`id_obat`) REFERENCES `obat` (`id_obat`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
