List<ProductCategoryProduct> lstUpdate = new List<ProductCategoryProduct>();

for ( ProductCategoryProduct rowProd : [
	SELECT Id, ProductCategoryId, ProductId, Product.Name, CatalogId FROM ProductCategoryProduct WHERE Product.Name = NULL

]){
    rowProd.ExistenciaC__c = 1000;
    lstUpdate.add(rowProd);
}

system.debug('lstUpdate.size() ' + lstUpdate.size());

if (lstUpdate.size() > 0) update lstUpdate;
