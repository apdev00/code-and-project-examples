USE [WideWorldImporters]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
	This stored procedure will take in the following parameters and return a data table containing
	the closest customers:

	@PostalCode			-- The postal code of the shop.
	@DistanceInMiles	-- The radius, in miles, to search from starting at the postal code.
	@CustomerTypes		-- A user-defined SQL Type, which is a table of customer types.
*/
ALTER PROCEDURE [dbo].[usp_GetClosestCustomerByZip]
(
	@PostalCode			nvarchar(15)
,	@DistanceInMiles	int
,	@CustomerTypes		CustomerTypeList READONLY
)
AS
BEGIN

	-- Use the Lookup.PostalCodes table to get the lat/long of the postal code
	DECLARE
		@PostalCodeLatitude float
	,	@PostalCodeLongitude float
	,	@PostalCodePoint	geography

	SELECT
		@PostalCodeLatitude = PostalCodeLatitude
	,	@PostalCodeLongitude = PostalCodeLongitude
	FROM
		Lookups.PostalCodes
	WHERE
		PostalCode = @PostalCode


	-- Generate the geo point to be used to calculate distance, with SRID = 4326
	SET @PostalCodePoint = geography::Point(@PostalCodeLatitude, @PostalCodeLongitude, 4326);


	-- Calculate distance for each customer from geo point
	SELECT
		c.CustomerGuid
	,	c.SiteNumber
	,	c.CustomerLocationCode
	,	c.CustomerFacilityName
	,	ct.CustomerTypeName
	,	ad.CityName
	,	ad.StateProvinceCode
	,	ad.LatitudeDecimal
	,	ad.LongitudeDecimal
	,	[DistanceInMiles] = (@PostalCodePoint.STDistance(ad.AddressGeoPoint) / 1609.355)
	INTO #Customers
	FROM Customers c
		LEFT OUTER JOIN CustomerTypes ct
			ON c.CustomerTypeGuid = ct.CustomerTypeGuid
		INNER JOIN CustomersToAddresses cta
			ON c.CustomerGuid = cta.CustomerGuid
		INNER JOIN Addresses ad
			ON cta.AddressGuid = ad.AddressGuid
	WHERE
		ct.CustomerTypeName IN (SELECT CustomerTypeName FROM @CustomerTypes)

	
	-- Return closest 100 customers
	SELECT TOP 100
		*
	FROM 
		#Customers
	WHERE
		DistanceInMiles <= (@DistanceInMiles + 1)
	ORDER BY
		[DistanceInMiles]
		

END