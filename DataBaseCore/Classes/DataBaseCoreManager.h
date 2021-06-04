//
//  DataBaseCoreManager.h
//  DataBaseCore
//
//  Created by ap on 2020/12/1.
//

#import <Foundation/Foundation.h>

static  NSString * _Nullable DB_Version = @"0.0.1";

NS_ASSUME_NONNULL_BEGIN

@interface DataBaseCoreConfig : NSObject

/// 文件夹名称
@property (nonatomic, copy) NSString *dirName;

/// 文件名称
@property (nonatomic, copy) NSString *fileName;

/// 文件扩展名
@property (nonatomic, copy) NSString *extension;

@property (nonatomic, copy) NSString *version;

@end

@interface DataBaseCoreManager : NSObject

/// 创建配置项
/// @param con 配置
-(instancetype)initWithConfig:(DataBaseCoreConfig*)con;

/// 创建表
/// @param name 表名称
/// @param modelClass 列model 名称
/// @param extra 额外字段 @{@"name":@"TXT"}
-(BOOL)createTable:(NSString*)name  modelColunms:(NSString*)modelClass extra:(nullable NSDictionary*)extra;

/// 创建表
/// @param name 表名称
/// @param colunmsDic 以字典的方式创建 @{@"name":@"TXT"}
-(BOOL)createTable:(NSString*)name  dicColunms:(NSDictionary*)colunmsDic;

/// 插入数据
/// @param name 表名称
/// @param model 数据
/// @param block 回调  失败 则row=-1
-(void)insertWithName:(NSString*)name  model:(id)model  block:(void(^)(NSInteger row))block;

/// 查询数据
/// @param name 表名
/// @param model 数据
/// @param con 条件 不让重复插入进行查询的条件如:{"id":"xxxx"}
/// @param block 回调
-(void)insertWithName:(NSString*)name  model:(id)model extraCondition:(nullable NSDictionary*)con block:(void(^)(NSInteger row))block;

/// 更新数据
/// @param name 表名称
/// @param model 数据
/// @param codition 条件
/// @param block 回调
-(void)updatetWithName:(NSString*)name  model:(id)model condition:(NSDictionary*)codition block:(void(^)(NSInteger row))block;

/// 删除数据
/// @param name 表名称
/// @param codition 条件
/// @param block 回调
-(void)deleteWithName:(NSString*)name  condition:(NSDictionary*)codition  block:(void(^)(NSInteger row))block;

/// 查询数据
/// @param name 表名
/// @param codition 条件字典
/// @param cls  model的class
/// @param block 回调
-(void)queryDataOfTableName:(NSString*)name  condition:(nullable NSDictionary*)codition model:(Class)cls primaryKey:(nullable NSString*)pKey block:(void(^)(NSArray*datas))block;

/// 删除表
/// @param name 表名称
/// @param block 回调
-(void)dropOfTableName:(NSString*)name block:(void(^)(BOOL success))block;

/// 以sql查询数据
/// @param sql sql
/// @param cls model 类
/// @param pKey model 类 的id
/// @param block 回调
-(void)queryDataWithSql:(NSString*)sql model:(Class)cls  primaryKey:(nullable NSString*)pKey  block:(void(^)(NSArray*datas))block;

/// 给表增加列
/// @param name 表名称
/// @param columns 列集合
-(void)addColumnForTable:(NSString*)name columns:(NSArray<NSDictionary*>*)columns;

@end

NS_ASSUME_NONNULL_END
