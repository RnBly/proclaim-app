// Kakao 로그인 JavaScript 헬퍼
window.kakaoLogin = {
  // 카카오 로그인 실행 (팝업)
  login: function() {
    return new Promise((resolve, reject) => {
      if (typeof Kakao === 'undefined') {
        reject({ error: 'Kakao SDK not loaded' });
        return;
      }

      // 팝업으로 로그인
      Kakao.Auth.login({
        success: function(authObj) {
          console.log('✅ Kakao auth success:', authObj);
          // 사용자 정보 가져오기
          window.kakaoLogin.getUserInfo()
            .then(userInfo => resolve(userInfo))
            .catch(err => reject(err));
        },
        fail: function(err) {
          console.error('❌ Kakao auth failed:', err);
          reject(err);
        }
      });
    });
  },

  // 사용자 정보 가져오기
  getUserInfo: function() {
    return new Promise((resolve, reject) => {
      Kakao.API.request({
        url: '/v2/user/me',
        success: function(response) {
          console.log('✅ Kakao user info:', response);
          const userInfo = {
            id: response.id.toString(),
            nickname: response.kakao_account?.profile?.nickname || '카카오 사용자',
            profileImage: response.kakao_account?.profile?.profile_image_url || '',
            email: response.kakao_account?.email || ''
          };
          resolve(userInfo);
        },
        fail: function(error) {
          console.error('❌ Failed to get user info:', error);
          reject(error);
        }
      });
    });
  },

  // 로그아웃
  logout: function() {
    return new Promise((resolve, reject) => {
      if (!Kakao.Auth.getAccessToken()) {
        resolve();
        return;
      }

      Kakao.Auth.logout(function() {
        console.log('✅ Kakao logout success');
        resolve();
      });
    });
  }
};