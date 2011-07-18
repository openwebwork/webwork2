## WeBWorK-tr  Turkish language lexicon

package WeBWorK::Localize::tr;

use base qw(WeBWorK::Localize);
use strict;
use vars qw(%Lexicon);

%Lexicon = (

## File locations
"navPrevGrey" =>			"images_tr/navPrevGrey",
"navPrev" =>				"images_tr/navPrev",
"navProbListGrey" =>			"images_tr/navProbListGrey",
"navProbList" =>			"images_tr/navProbList",
"navNextGrey" =>			"images_tr/navNextGrey",
"navNext" =>				"images_tr/navNext",
"navUp" =>				"images_tr/navUp",

## UNTRANSLATED

"The selected problem([_1]) is not a valid problem for set [_2]." =>
	"The selected problem([_1]) is not a valid problem for set [_2].", 

"Download Hardcopy for Selected [plural,_1,Set,Sets]" => 
	"Seçili Setleri Yazdır: [plural,_1,Set,Sets]",  



"[_1]: Problem [_2]." =>		"[_1]: Soru [_2].", ## ozcan
"Next Problem" =>			"Sonraki Soru",  ## ozcan
"Previous Problem" =>			"Önceki Soru", ## ozcan
"Problem List" =>			"Soru Listesi", ## ozcan
"now open, due " =>			"açık, bitiş tarihi: ", ## ozcan
"Set" =>				"Soru Grubu", ## ozcan
"Score" =>				"Not", ## ozcan
"Problems" =>				"Sorular", ## ozcan
"You can earn partial credit on this problem." =>
	"Bu sorudan kısmi puan alabilirsiniz.", ## ozcan
"You have [negquant,_1,unlimited attempts,attempt,attempts] remaining." =>
	"[negquant,_1,Sınırsız deneme hakkı,deneme hakkı,deneme hakkı] kaldı.", ## ozcan

## TRANSLATED BY SALIH

"over time: closed." =>			"süre bitti: kapalı.",
"open: complete by [_1]" =>		"açık: [_1] tarihine kadar tamamlayın",
"will open on [_1]" =>			"[_1] tarihinde açılacak",
"closed, answers on [_1]" =>		"kapalı, cevaplar [_1] tarihinde",
"closed, answers recently available" =>	"kapalı, cevaplar yeni açıklandı",
"closed, answers available" =>		"kapalı, cevaplar açıklandı",
"Viewing temporary file: " =>		"Geçici dosyayı görüntülüyor: ",
"Course Info" =>			"Ders bilgileri",
"~[edit~]" =>				"~[düzenle~]",    ## edited - ozcan
"Course Administration" =>		"Ders Yönetimi",
"Feedback" =>				"Geri Bildirim",
"Grades" =>				"Notlar",
"Instructor Tools" =>			"Eğitmen Araçları",
"Classlist Editor" =>			"Sınıf Listesi Düzenleyici",
"Hmwk Sets Editor" =>			"Ödev Setleri Düzenleyici",
"Add Users" =>				"Kullanıcı Ekle",
"Course Configuration" =>		"Ders Seçenekleri",
"Library Browser" =>			"Kütüphane Tarayıcı",
"File Manager" =>			"Dosya Yöneticisi",
"Problem Editor" =>			"Soru Düzenleyici",
"Scoring Tools" =>			"Notlama Araçları",
"Scoring Download" =>			"Notları İndir",
"Email" =>				"E-posta",
"Email instructor" =>			"Eğitmene E-posta",
"Logout" => 				"Çıkış",
"Password/Email" =>			"Şifre/E-posta",
"Statistics" =>				"İstatistikler",

## TRANSLATED by OZCAN


"Courses" =>		"Dersler",
"Homework Sets" => 	"Soru Grupları",
"Problem [_1]" => 	"Soru [_1]",
"Library Browser" => 	"Soru Kütüphaneleri",
"Report bugs" => 	"Hataları bildir",

"Logged in as [_1]. " => "[_1] olarak giriş yaptınız.",
"Log Out" => 		"Çıkış Yap",
"Not logged in." => 	"Giriş yapmadınız.",
"Acting as [_1]. " =>  	"[_1] gibi davranılıyor.",
"Stop Acting" => 	"Rol Yapmayı bırak",

"Welcome to WeBWorK!" => "WeBWorK sitemize hoşgeldiniz!",
"Messages" => 		"Mesajlar",
"Entered" => 		"Yanıt",
"Result" => 		"Sonuç",
"Answer Preview" => 	"Gösterim",

"Correct" => 		"Doğru yanıt",
"correct" => 		"doğru",
"[_1]% correct" => 	"[_1]% doğru",
"incorrect" => 		"yanlış",
"Published" => 		"Yayınlandı",

"Unpublished" => 	"Yayınlanmadı",
"Show Hints" => 	"İpuçlarını göster",
"Show Solutions" => 	"Çözümleri göster",
"Preview Answers" => 	"Yanıtları görüntüle",
"Check Answers" => 	"Yanıtları kontrol et",

"Submit Answers" => 	"Yanıtları Gönder",
"Submit Answers for [_1]" => 
	"[_1] için Yanıtları Gönder",
"times" => 		"deneme hakkı",
"time" => 		"deneme hakkı",
"unlimited" =>  	"sınırsız",

"attempts" =>  		"deneme hakkı",
"attempt" => 		"deneme hakkı",
"Name" => 		"Grup Adı", ## edited - ozcan
"Attempts" => 		"Deneme sayısı",
"Remaining" => 		"Kalan hak",

"Worth" => 		"Değeri",
"Status" => 		"Durumu",
"Change Password" => 		"Şifre Değiştir",
"[_1]'s Current Password" => 	"[_1] için Mevcut Şifre",
"[_1]'s New Password" => 	"[_1] için Yeni Şifre",

"Change Email Address" => 	"E-posta Adresi Değiştir",
"[_1]'s Current Address" => 	"[_1] için Mevcut Adres",
"[_1]'s New Address" => 	"[_1] için Yeni Adres",
"Change User Options" => 	"Kullanıcı bilgilerini güncelle",
"Your score was recorded." => 	"Notunuz kaydedildi.",

"Show correct answers" => 	"Doğru yanıtları göster",
"This homework set is closed." => "Bu soru grubu kapalı.",
"Show Past Answers" => 		"Önceki Yanıtları Göster",
"Log In Again" => 		"Tekrar giriş yap",


"The answer above is correct." => 
	"Yukarıdaki yanıt doğru.",

"The answer above is NOT [_1]correct." => 
	"Yukarıdaki yanıt [_1]doğru değil.",

"All of the answers above are correct." => 
	"Yanıtların tümü doğru",

"At least one of the answers above is NOT [_1]correct." => 
	"Yanıtların en az bir tanesi [_1]doğru değil.",

"[quant,_1,of the questions remains,of the questions remain] unanswered." => 
	"Soruların [_1] tanesi yanıtsız bırakıldı.",

"This set is [_1] students." =>	
	"Bu soru grubu öğrenciler tarafından [_1].",

"visible to" => 
	"görüntüleniyor",

"hidden from" => 
	"görüntülenmiyor",

"This problem will not count towards your grade." => 
	"Bu soru, notunuzu etkilemeyecektir.",

"The selected problem ([_1]) is not a valid problem for set [_2]." =>
	"Seçilen problem ([_1]), [_2] soru drubu için geçerli bir soru değil.",

"You do not have permission to view the details of this error." => 
	"Bu hatanın detaylarını görmeye yetkiniz yok.",

"Your score was not recorded because there was a failure in storing the problem record to the database." =>
	"Notunuz kaydedilemedi, çünkü notun veritabanına kaydı sırasında bir hata oluştu.",

"Your score was not recorded because this homework set is closed." =>
	"Notunuz kaydedilemedi çünkü bu soru grubu kapalı.",

"Your score was not recorded because this problem has not been assigned to you." =>
	"Notunuz kaydedilmedi çünkü bu soru size yöneltilmedi.",

"Viewing temporary file: " => 	
	"Geçici dosya görüntüleniyor: ",

"ANSWERS ONLY CHECKED -- ANSWERS NOT RECORDED" => 
	"YANITLAR SADECE KONTROL EDİLİYOR -- YANITLAR KAYDEDİLMEDİ",

"PREVIEW ONLY -- ANSWERS NOT RECORDED" => 
	"GÖSTERİM -- YANITLAR KAYDEDİLMEDİ ",

"submit button clicked" =>
 	"gönder düğmesine basıldı",

"This homework set is not yet open." => 
	"Bu soru grubu henüz açık değil.",

"(This problem will not count towards your grade.)" => 
	"(Bu soru notunuzu etkilemeyecektir.)",

"You have attempted this problem [quant,_1,time,times]." => 
	"Bu soru için [quant,_1,deneme hakkı,deneme hakkı] kullandınız.",

"You received a score of [_1] for this attempt." => 
	"Bu soru için [_1] puan aldınız.",

"Your overall recorded score is [_1].  [_2]" => 
	"Ortalama puanınız: [_1].  [_2]",

"You have [_1] [_2] remaining." => 
	"[_1] [_2] kaldı.",

"Download a hardcopy of this homework set." => 
	"Bu soru grubunu basılı halde indirin." ,

"This homework set contains no problems." => 
	"Bu soru grubunda soru bulunmamaktadır.",

"Can't get password record for user '[_1]': [_2]" => 
	"Can't get password record for user '[_1]': [_2]",

"Can't get password record for effective user '[_1]': [_2]" => 
	"Can't get password record for effective user '[_1]': [_2]",

"Couldn't change [_1]'s password: [_2]" => 
	"[_1] adlı kullanıcının şifresi değiştirilemedi: [_2]",

"[_1]'s password has been changed." => 
	"[_1] adlı kullanıcının şifresi değiştirildi.",

"The passwords you entered in the [_1] and [_2] fields don't match. Please retype your new password and try again." =>
   "[_1] ve [_2]  alanlarına girdiğiniz şifreler uyuşmadı. Yeni şifrenizi girerek tekrar deneyiniz.",

"Confirm [_1]'s New Password" => 
	"[_1] için Şifre Onayı",

"[_1]'s new password cannot be blank." => 
	"[_1] için yeni şifre boş bırakılamaz.",

"The password you entered in the [_1] field does not match your current password. 
Please retype your current password and try again." => 
	"[_1] alanına girdiğiniz şifre ile mevcut şifreniz uyuşmamaktadır. Lütfen şirfenizi girerek tekrar deneyiniz.",

"You do not have permission to change your password." => 
	"Şifre değiştirmek için yetkiniz yok.",

"Couldn't change your email address: [_1]" => 
	"E-posta adresiniz değiştirilemedi: [_1]", 

"Your email address has been changed." => 
	"E-posta adresiniz değiştirildi.",

"You do not have permission to change email addresses." => 
	"Adres değiştirmek için yetkiniz yok.",

"You have been logged out of WeBWorK." => 
	"WeBWorK sisteminden çıkış yaptınız.", 

"Invalid user ID or password." =>
	"Yanlış kullanıcı adı ya da şifre.",

"You must specify a user ID." =>
	"Bir kullanıcı adı girmelisiniz.",

"Your session has timed out due to inactivity. Please log in again." => 
	"Oturumunuz zaman aşımına uğradı. Lütfen tekrar giriş yapınız.",

"_REQUEST_ERROR" => q{
 WebWork bu problemi işlerken bir yazılım hatası ile karşılaştı. Problemin kendisinde bir hata olması muhtemeldir. Eğer bir öğrenci iseniz bu hatayı ilgili kişilere bildiriniz. Eğer yetkili bir kişiyseniz daha fazla bilgi için alttaki hata raporunu inceleyiniz.
},
);
1;

