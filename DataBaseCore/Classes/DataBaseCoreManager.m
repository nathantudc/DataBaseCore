//
//  DataBaseCoreManager.m
//  DataBaseCore
//
//  Created by ap on 2020/12/1.
//

#import "DataBaseCoreManager.h"
#import <fmdb/FMDB.h>
#import <pthread.h>
#import <sqlite3.h>
#import "MJExtension.h"

@implementation DataBaseCoreConfig

@end

@interface DataBaseCoreManager ()

//@property (nonatomic, strong) FMDatabaseQueue *queue;
@property (nonatomic, strong) FMDatabasePool *queue;
@property (nonatomic, strong) NSDictionary *colunmsFields;

@end

@implementation DataBaseCoreManager{
    pthread_mutex_t _dbLock;
    DataBaseCoreConfig *_con;
}


//- (instancetype)init{
//    self = [super init];
//    if (self) {
//        pthread_mutex_init(&_dbLock, NULL);
//    }
//    return self;
//}

- (void)dealloc{
    pthread_mutex_destroy(&_dbLock);
}

- (void)receiveMemoryWarning{
    pthread_mutex_lock(&_dbLock);
    _queue = nil;
    pthread_mutex_unlock(&_dbLock);
}

-(instancetype)initWithConfig:(DataBaseCoreConfig*)con{
    self = [super init];
    if (self) {
        _con = con;
        pthread_mutex_init(&_dbLock, NULL);
    }
    return self;
}

#pragma mark - 删除表
-(void)dropOfTableName:(NSString*)name block:(void(^)(BOOL success))block{
    NSAssert(name,@"colunmsFields must not nil");
    NSString *sql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@ ;", name];
    __block BOOL result = NO;
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql];
    }];
    block?block(result):nil;
}

#pragma mark - 创建表
/// 创建表
/// @param name 表名称
/// @param modelClass 列model 名称
/// @param extra 额外字段
-(BOOL)createTable:(NSString*)name  modelColunms:(NSString*)modelClass extra:(nullable NSDictionary*)extra{
     NSAssert(name,@"tablename must not  nil");
     NSAssert(_con,@"configer must not  nil");
     NSAssert(_con.dirName,@"dirName must not  nil");
     NSAssert(_con.fileName,@"fileName must not  nil");
     NSAssert(_con.extension,@"extension must not  nil");
//     [self versionControl];
     NSMutableDictionary *colunms = [NSMutableDictionary dictionary];
     Class cls = NSClassFromString(modelClass);
     [cls mj_enumerateProperties:^(MJProperty *property, BOOL *stop) {
        [colunms addEntriesFromDictionary:[self _propertyToSqlType:property]];
     }];
     if(extra && extra.count >0)[colunms addEntriesFromDictionary:extra];
     _colunmsFields = [colunms copy];
     return [self createTableIfNotExistsWithName:name];
}

-(BOOL)createTable:(NSString*)name  modelColunms:(NSString*)modelClass unique:(nullable NSString*)unique
{
     NSAssert(name,@"tablename must not  nil");
     NSAssert(_con,@"configer must not  nil");
     NSAssert(_con.dirName,@"dirName must not  nil");
     NSAssert(_con.fileName,@"fileName must not  nil");
     NSAssert(_con.extension,@"extension must not  nil");
      NSMutableDictionary *colunms = [NSMutableDictionary dictionary];
     Class cls = NSClassFromString(modelClass);
     [cls mj_enumerateProperties:^(MJProperty *property, BOOL *stop) {
        [colunms addEntriesFromDictionary:[self _propertyToSqlType:property]];
     }];
      _colunmsFields = [colunms copy];
    if (unique && unique.length > 0)
    {
        NSString *str = [NSString stringWithFormat:@"CREATE TABLE  IF NOT EXISTS %@ (id INTEGER PRIMARY KEY AUTOINCREMENT,", name];
        NSMutableString *sql = [[NSMutableString alloc] initWithString:str];
        NSInteger lastCount = self.colunmsFields.count-1;
        [self.colunmsFields.allKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL * _Nonnull stop) {
           [sql appendFormat:@" %@ %@",key,self.colunmsFields[key]];
           if (idx != lastCount)[sql appendString:@", "];
        }];
        [sql appendFormat:@", _reserve TEXT, UNIQUE(%@))",unique];
//        [sql appendString:@", _reserve TEXT);"];
        __block BOOL result = NO;
        [self.databaseQueue inDatabase:^(FMDatabase *db) {
            result = [db executeUpdate:sql];
            [db close];
        }];
        return result;
    }
     return [self createTableIfNotExistsWithName:name];
}

/// 创建表
/// @param name 表名称
/// @param colunmsDic 以字典的方式创建
-(BOOL)createTable:(NSString*)name  dicColunms:(NSDictionary*)colunmsDic{
    NSAssert(colunmsDic.count==0,@"colunmsDic must not  nil");
    NSAssert(!_con,@"configer must not  nil");
    NSAssert(!_con.dirName,@"dirName must not  nil");
    NSAssert(!_con.fileName,@"fileName must not  nil");
    NSAssert(!_con.extension,@"extension must not  nil");
//    [self versionControl];
    _colunmsFields = [colunmsDic copy];
    return [self createTableIfNotExistsWithName:name];
}

-(NSDictionary *)_propertyToSqlType:(MJProperty *)pro{
    NSDictionary *switchD = @{@"d":@"FLOAT",@"q":@"INTEGER", @"f":@"REAL", @"d":@"REAL", @"NSString":@"TEXT DEFAULT ''", @"B":@"INTEGER"};
    if (switchD[pro.type.code] == nil) {
        return @{pro.name: @"TEXT"};//默认TEXT存储类型
    }
    return @{pro.name:switchD[pro.type.code]};
}

#pragma mark  - 插入数据

- (void)insertWithName:(NSString*)name  model:(id)model  block:(void(^)(NSInteger row))block{
    NSAssert(name,@"colunmsDic must not  nil");
    NSAssert(model,@"colunmsDic must not  nil");
    NSString *sqlStr = [self insertExecuteSQLOfTableName:name dataDic:[model mj_keyValues]];
    __block BOOL result = NO;
    __block NSInteger row = 0;
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sqlStr];
        row = db.lastInsertRowId;
        [db close];
    }];
    block?block(result?row:-1):nil;
}

-(void)insertWithName:(NSString*)name model:(id)model extraCondition:(nullable NSDictionary*)con block:(void(^)(NSInteger row))block{
    if (con.count == 0) {
        [self insertWithName:name model:model block:block];
        return;
    }
    [self queryDataOfTableName:name condition:con model:[model class] primaryKey:nil block:^(NSArray * _Nonnull datas) {
        if (datas.count > 0) return;
        [self insertWithName:name model:model block:block];
    }];
}

-(NSString*)insertExecuteSQLOfTableName:(NSString*)name  dataDic:(NSDictionary*)dic{
    NSMutableString *sql = [[NSMutableString alloc] initWithFormat:@"INSERT OR REPLACE INTO %@ ", name];
    NSMutableString *values= [[NSMutableString alloc] initWithFormat:@"("];
    NSMutableString *keys = [[NSMutableString alloc] initWithFormat:@"("];
    NSInteger lastCount = dic.count - 1;
    [dic.allKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL * _Nonnull stop) {
         [keys appendString:key];
         id value = dic[key];
        if ([value isKindOfClass:[NSString class]]) {
            [values appendFormat:@"'%@'",value];
        }else
            [values appendFormat:@"%@",value];
        if (idx != lastCount){
           [keys appendString:@", "];
           [values appendString:@", "];
        }
    }];
    [keys appendString:@") "];
    [values appendString:@");"];
    [sql appendFormat:@"%@ VALUES %@", keys, values];
    return [sql copy];
}

#pragma mark - 查询数据
-(void)queryDataOfTableName:(NSString*)name  condition:(nullable NSDictionary*)codition model:(Class)class primaryKey:(nullable NSString*)pKey block:(void(^)(NSArray*datas))block{
    NSMutableString *querySql = [NSMutableString stringWithFormat:@"SELECT * FROM %@ ", name];
    NSInteger lastIndex = (codition.count-1);
    NSMutableString *values = [NSMutableString string];
    [codition.allKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL * _Nonnull stop) {
        id value = codition[key];
        if ([value isKindOfClass:[NSString class]]) {
            [values appendFormat:@" %@ = '%@'",key,value];
        }else
            [values appendFormat:@" %@ = %@",key,value];
        if (idx != lastIndex)[values appendString:@" and "];
    }];
    if (values.length >0) [querySql appendFormat:@" WHERE %@", values];
    [querySql appendString:@";"];
    NSMutableArray *keys = [NSMutableArray array];
    NSMutableArray *resArr = [NSMutableArray array];
    [class mj_enumerateProperties:^(MJProperty *property, BOOL *stop) {
        [keys addObjectsFromArray:[self _propertyToSqlType:property].allKeys];
    }];
    if ([class respondsToSelector:@selector(mj_ignoredPropertyNames)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSArray *subArray = [class performSelector:@selector(mj_ignoredPropertyNames)];
#pragma clang diagnostic pop
        if (subArray) {
            [keys removeObjectsInArray:subArray];
        }
    }
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *set = [db executeQuery:querySql];
        while (set.next) {
            id data = [class new];
            for (NSString *key in keys) {
                id value = [set objectForColumn:key];
                if (value && ![value isKindOfClass:[NSNull class]]){
                    [data setValue:value forKey:key];
                }
            }
            if (pKey)[data setValue:[set objectForColumn:@"id"] forKey:pKey];
            [resArr addObject:data];
        }
        [db close];
    }];
    block?block(resArr):nil;
}

#pragma mark - 查询数据
-(void)queryDataWithSql:(NSString*)sql model:(Class)class primaryKey:(nullable NSString*)pKey block:(void(^)(NSArray*datas))block{
//-(void)queryDataWithSql:(NSString*)sql model:(Class)class block:(void(^)(NSArray*datas))block{
    NSAssert(sql,@"query sql must be not  nil");
    NSAssert(class,@"cls must  be not  nil");
    NSMutableArray *keys = [NSMutableArray array];
    NSMutableArray *resultArray= [NSMutableArray array];
    [class mj_enumerateProperties:^(MJProperty *property, BOOL *stop) {
        [keys addObjectsFromArray:[self _propertyToSqlType:property].allKeys];
    }];
    if ([class respondsToSelector:@selector(mj_ignoredPropertyNames)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSArray *subArray = [class performSelector:@selector(mj_ignoredPropertyNames)];
#pragma clang diagnostic pop
        if (subArray) [keys removeObjectsInArray:subArray];
    }
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        FMResultSet *set = [db executeQuery:sql];
        while (set.next) {
            id model = [class new];
            for (NSString *key in keys) {
                id value = [set objectForColumn:key];
                if (value && ![value isKindOfClass:[NSNull class]]){
                    [model setValue:value forKey:key];
                }
            }
            if (pKey)[model setValue:[set objectForColumn:@"id"] forKey:pKey];
            [resultArray addObject:model];
        }
        [db close];
    }];
    block?block(resultArray):nil;
}

#pragma mark - 更新数据

-(void)updatetWithName:(NSString*)name  model:(id)model condition:(NSDictionary*)codition block:(void(^)(NSInteger row))block{
    NSMutableString *sql = [NSMutableString stringWithFormat:@"UPDATE %@ ", name];
    NSMutableString *values = [NSMutableString string];
    NSDictionary*modelKeyValues = [model mj_keyValues];
    NSInteger lastIndex = modelKeyValues.count-1;
    [modelKeyValues.allKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL * _Nonnull stop) {
        id value = modelKeyValues[key];
        if ([value isKindOfClass:[NSString class]]) {
            [values appendFormat:@" %@='%@' ",key,value];
        }else
            [values appendFormat:@" %@=%@ ",key,value];
        if (idx != lastIndex)[values appendString:@","];
    }];
    [sql appendFormat:@" SET %@", values];
    NSMutableString *cons = [NSMutableString string];
    [codition.allKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id value = codition[obj];
        if ([value isKindOfClass:[NSString class]]) {
           [cons appendFormat:@" %@='%@' ",obj,value];
        }else
           [cons appendFormat:@" %@=%@ ",obj,value];
        if (idx != (codition.count-1))[cons appendString:@" AND "];
    }];
    
    [sql appendFormat:@" WHERE %@", cons];
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
         BOOL result = [db executeUpdate:sql];
        [db close];
         block?block(result?1:-1):nil;
    }];
}

#pragma mark - 删除数据

-(void)deleteWithName:(NSString*)name  condition:(NSDictionary*)condition  block:(void(^)(NSInteger row))block{
    NSMutableString *sql = [NSMutableString stringWithFormat:@"DELETE FROM %@",name];
    NSMutableString *conS = [NSMutableString string];
    [condition.allKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL * _Nonnull stop) {
//        if ([key isEqualToString:@"id"]) {
//
//        }else
        [conS appendFormat:@" %@ = %@ ",key, condition[key]];
        if (idx != condition.count-1)[conS appendString:@" AND "];
    }];
    if (conS.length>0)[sql appendFormat:@" WHERE %@",conS];
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
         BOOL result = [db executeUpdate:sql];
        [db close];
         block?block(result?1:-1):nil;
    }];
}

#pragma mark - 添加列

-(void)addColumnForTable:(NSString*)name columns:(NSArray<NSDictionary*>*)columns{
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        [columns enumerateObjectsUsingBlock:^(NSDictionary*dic, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString* querySql = [NSString stringWithFormat:@"select * from sqlite_master where name='%@' and sql like '%%%@%%'",name,dic[@"name"]];
            FMResultSet *rs = [db executeQuery:querySql];
            if (![rs next]) {
                NSString *addSql = [NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@",name,dic[@"name"],dic[@"type"]];
                if (![db executeUpdate:addSql])NSLog(@"ADD COLUMN faile");
            }
        }];
        [db close];
    }];
}

#pragma mark - layzing
-(FMDatabasePool *)databaseQueue {
   NSAssert(_con,@"configer must not  nil");
   NSAssert(_con.dirName,@"dirName must not  nil");
   NSAssert(_con.fileName,@"fileName must not  nil");
   NSAssert(_con.extension,@"extension must not  nil");
    pthread_mutex_lock(&_dbLock);
    if (!_queue) {
        NSString *path = [self createFileWithDesDir:_con.dirName fileNmae:_con.fileName extension:_con.extension];
//        _queue = [FMDatabaseQueue databaseQueueWithPath:path flags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE];
        _queue = [FMDatabasePool databasePoolWithPath:path flags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE];
    }
    pthread_mutex_unlock(&_dbLock);
    return _queue;
}

#pragma mark - extra method
#define TDC_DBVERSION          @"TDC_DBVersion"
-(void)versionControl{
    NSString * version_old = [[NSUserDefaults standardUserDefaults] stringForKey:TDC_DBVERSION];
    NSString * version_new = [NSString stringWithFormat:@"%@",DB_Version];
    if (_con && _con.version) version_new = [NSString stringWithFormat:@"%@",_con.version];
    if (!version_old ||
        [version_new isEqualToString:version_old]) {
        [[NSUserDefaults standardUserDefaults] setObject:version_new forKey:TDC_DBVERSION];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return;
    }
    NSArray* existsTables = [self sqliteExistsTables];
    NSMutableArray* tmpExistsTables = [NSMutableArray array];
    for (NSString* tablename in existsTables) {
        @autoreleasepool {
          [tmpExistsTables addObject:[NSString stringWithFormat:@"%@_bak", tablename]];
          [self.queue inDatabase:^(FMDatabase *db) {
              NSString* sql = [NSString stringWithFormat:@"ALTER TABLE %@ RENAME TO %@_bak", tablename, tablename];
              [db executeUpdate:sql];
          }];
        }
    }
    existsTables = tmpExistsTables;
    NSArray* newAddedTables = [self sqliteNewAddedTables];
    NSDictionary* migrationInfos = [self generateMigrationInfosWithOldTables:existsTables newTables:newAddedTables];
    [migrationInfos enumerateKeysAndObjectsUsingBlock:^(NSString* newTableName, NSArray* publicColumns, BOOL * _Nonnull stop) {
        NSMutableString* colunmsString = [NSMutableString new];
        NSInteger lastIndex = publicColumns.count-1;
        [publicColumns enumerateObjectsUsingBlock:^(NSString *column, NSUInteger idx, BOOL * _Nonnull stop) {
              [colunmsString appendString:column];
              if (idx != lastIndex) {
                [colunmsString appendString:@", "];
             }
        }];
        NSMutableString* sql = [NSMutableString new];
        [sql appendString:@"INSERT INTO "];
        [sql appendString:newTableName];
        [sql appendString:@"("];
        [sql appendString:colunmsString];
        [sql appendString:@")"];
        [sql appendString:@" SELECT "];
        [sql appendString:colunmsString];
        [sql appendString:@" FROM "];
        [sql appendFormat:@"%@_bak", newTableName];
        [self.databaseQueue inDatabase:^(FMDatabase *db) {
           BOOL result = [db executeUpdate:sql];
           #if defined(DEBUG) && DEBUG
              if (!result) NSLog(@"数据导入出错");
           #endif
        }];
    }];
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        [db beginTransaction];
        [existsTables enumerateObjectsUsingBlock:^(NSString *oldTableName, NSUInteger idx, BOOL * _Nonnull stop) {
           NSString* sql = [NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", oldTableName];
           BOOL result = [db executeUpdate:sql];
           #if defined(DEBUG) && DEBUG
              if (!result)NSLog(@"删除数据库出错");
           #endif
        }];
        [db commit];
    }];
    [[NSUserDefaults standardUserDefaults] setObject:version_new forKey:TDC_DBVERSION];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDictionary*)generateMigrationInfosWithOldTables:(NSArray*)oldTables newTables:(NSArray*)newTables {
    NSMutableDictionary<NSString*, NSArray* >* migrationInfos = [NSMutableDictionary dictionary];
    [newTables enumerateObjectsUsingBlock:^(NSString *newTableName, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString* oldTableName = [NSString stringWithFormat:@"%@_bak", newTableName];
        if ([oldTables containsObject:oldTableName]) {
            NSArray* oldTableColumns = [self sqliteTableColumnsWithTableName:oldTableName];
            NSArray* newTableColumns = [self sqliteTableColumnsWithTableName:newTableName];
            NSArray* publicColumns = [self publicColumnsWithOldTableColumns:oldTableColumns newTableColumns:newTableColumns];
            if (publicColumns.count > 0) {
                [migrationInfos setObject:publicColumns forKey:newTableName];
            }
        }
    }];
    return migrationInfos;
}

- (NSArray*)publicColumnsWithOldTableColumns:(NSArray*)oldTableColumns newTableColumns:(NSArray*)newTableColumns {
    NSMutableArray* publicColumns = [NSMutableArray array];
    for (NSString* oldTableColumn in oldTableColumns) {
        if ([newTableColumns containsObject:oldTableColumn]) {
            [publicColumns addObject:oldTableColumn];
        }
    }
    return publicColumns;
}

- (NSArray*)sqliteTableColumnsWithTableName:(NSString*)tableName {
    __block NSMutableArray<NSString*>* tableColumes = [NSMutableArray array];
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        NSString* sql = [NSString stringWithFormat:@"PRAGMA table_info('%@')", tableName];
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            NSString* columnName = [rs stringForColumn:@"name"];
            [tableColumes addObject:columnName];
        }
    }];
    return tableColumes;
}

- (NSArray*)sqliteExistsTables {
    __block NSMutableArray<NSString*>* existsTables = [NSMutableArray array];
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        NSString* sql = @"SELECT * from sqlite_master WHERE type='table'";
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            NSString* tablename = [rs stringForColumn:@"name"];
            [existsTables addObject:tablename];
        }
    }];
    return existsTables;
}

- (NSArray*)sqliteNewAddedTables {
    __block NSMutableArray<NSString*>* newAddedTables = [NSMutableArray array];
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        NSString* sql = @"SELECT * from sqlite_master WHERE type='table' AND name NOT LIKE '%_bak'";
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            NSString* tablename = [rs stringForColumn:@"name"];
            [newAddedTables addObject:tablename];
        }
    }];
    return newAddedTables;
}

-(BOOL)createTableIfNotExistsWithName:(NSString*)name{
    NSAssert(self.colunmsFields,@"colunmsFields must not nil");
    NSString *str = [NSString stringWithFormat:@"CREATE TABLE  IF NOT EXISTS %@ (id INTEGER PRIMARY KEY AUTOINCREMENT,", name];
    NSMutableString *sql = [[NSMutableString alloc] initWithString:str];
    NSInteger lastCount = self.colunmsFields.count-1;
    [self.colunmsFields.allKeys enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL * _Nonnull stop) {
       [sql appendFormat:@" %@ %@",key,self.colunmsFields[key]];
       if (idx != lastCount)[sql appendString:@", "];
    }];
    [sql appendString:@", _reserve TEXT);"];
    __block BOOL result = NO;
    [self.databaseQueue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql];
        [db close];
    }];
    return result;
}

-(NSString*)createFileWithDesDir:(NSString*)dir fileNmae:(NSString*)file extension:(NSString*)ex{
   NSString *documentsDir = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
   documentsDir = [documentsDir stringByAppendingPathComponent:dir];
   NSFileManager *filemanager = [NSFileManager defaultManager];
   BOOL isDir;
   BOOL isExit = [filemanager fileExistsAtPath:documentsDir isDirectory:&isDir];
   if (!isExit || !isDir) {
       [filemanager createDirectoryAtPath:documentsDir withIntermediateDirectories:YES attributes:nil error:nil];
   }
   documentsDir = [documentsDir stringByAppendingPathComponent:file];
   documentsDir = [documentsDir stringByAppendingPathExtension:ex];
   return documentsDir;
}

@end
