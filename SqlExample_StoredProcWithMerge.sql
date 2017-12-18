USE [WideWorldImporters]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
	This stored procedure will run after an online transaction has taken place, so that the product inventory can be updated.
	An audit record is the inserted into the inventory audit table.
*/
ALTER PROCEDURE [Sales].[usp_UpdateProductInventory]
AS
BEGIN
	DECLARE @MergeOutput TABLE
	(
		ActionType		nvarchar(10),
		DelProductId	int,
		InsProductId	int,
		DelProduct		nvarchar(50),
		InsProduct		nvarchar(50),
		DelQuantity		int,
		InsQuantity		int
	);

	-- Update ProductInventory using a MERGE statement
	MERGE 
		Sales.ProductInventory i
	USING 
		Sales.ProductOrder po
	ON 
		i.ProductId = po.ProductId
	WHEN MATCHED AND (i.Quantity + po.Quantity = 0) 
		THEN DELETE
	WHEN MATCHED 
		THEN UPDATE
			SET i.Quantity = i.Quantity + po.Quantity
	WHEN NOT MATCHED BY TARGET 
		THEN INSERT 
			(ProductId, Product, Quantity)
		VALUES 
			(po.TitleID, po.Title, po.Quantity)
	WHEN NOT MATCHED BY SOURCE AND (i.Quantity = 0) 
		THEN DELETE
	OUTPUT
		$action,
		DELETED.ProductId,
		INSERTED.ProductId,
		DELETED.Product,
		INSERTED.Product,
		DELETED.Quantity,
		INSERTED.Quantity
	INTO @MergeOutput;

	-- Insert the MERGE output into inventory audit table

	INSERT INTO Audit.ProductInventory
	(
		ActionType
	,	ProductId_Deleted
	,	ProductId_Inserted
	,	Product_Deleted
	,	Product_Inserted
	,	Quantity_Deleted
	,	Quantity_Inserted
	,	DateTimeRecordAudited
	)
	SELECT
		ActionType
	,	DelProduct
	,	InsProductId
	,	DelProduct
	,	InsProduct
	,	DelQuantity
	,	InsQuantity
	,	GETDATE()
	FROM @MergeOutput;

END