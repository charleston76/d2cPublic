// Delete all product media found
// You can adjust this code or any other, to achieve your needs
List<ProductMedia> delProductMedia = [SELECT Id FROM ProductMedia];
delete delProductMedia;

System.debug('delProductMedia.size() ' + delProductMedia.size() );

// List<ProductCategoryMedia> delProductCategoryMedia = [SELECT Id FROM ProductCategoryMedia];
// delete delProductCategoryMedia;

// System.debug('delProductCategoryMedia.size() ' + delProductCategoryMedia.size() );